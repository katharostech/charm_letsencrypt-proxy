#!/bin/bash

set -ex

# If we are not ready to start yet, exit early
if [ "$(lucky kv get start_server)" != "true" ]; then exit 0; fi

# If we are the leader, ignore leader-settings-changed hooks
if [ "$(lucky leader is-leader)" = "true" -a "$LUCKY_HOOK" = "leader-settings-changed" ]; then exit 0; fi

lucky set-status maintenance "Configuring Proxy"

# Set container image
lucky container image set katharostech/charm_letsencrypt-proxy:latest

# Set host networking mode
lucky container set-network host

# Set test mode based on charm config
previous_test_mode="$(lucky kv get test_mode)"
current_test_mode="$(lucky get-config test)"
lucky container env set "TEST=$current_test_mode"
lucky kv set "test_mode=$current_test_mode"

# Set the acme cfg base64 encoded tar to restore the acme.sh config
# If the previous value of TEST was different we need to clean out the acme config to force the
# certs to regenerate.
if [ "$previous_test_mode" != "$current_test_mode" ]; then
    # Clear the acme config
    lucky leader set "acme_cfg_base64="
    lucky container env set "ACME_CFG_BASE64="
else
    # Set the acme config
    lucky container env set "ACME_CFG_BASE64=$(lucky leader get acme_cfg_base64)"
fi

# Set leader config
lucky container env set "IS_LEADER=$(lucky leader is-leader)"

# Create the haproxy config template data YAML
tpl_data=""

# Configure proxy ports ( get port setting from kv store or generate random available port )
internal_acme_port=$(lucky kv get internal_acme_port)
internal_acme_port=${internal_acme_port:-$(lucky random --available-port)}
lucky kv set "internal_acme_port=$internal_acme_port"

internal_https_port=$(lucky kv get internal_https_port)
internal_https_port=${internal_https_port:-$(lucky random --available-port)}
lucky kv set "internal_https_port=$internal_https_port"

haproxy_logging_port=$(lucky kv get haproxy_logging_port)
haproxy_logging_port=${haproxy_logging_port:-$(lucky random --available-port)}
lucky kv set "haproxy_logging_port=$haproxy_logging_port"

http_port=$(lucky get-config http-port)
https_port=$(lucky get-config https-port)

# Close previously opened ports
lucky port close --all

# Open https and http ports
lucky port open $http_port
lucky port open $https_port

tpl_data="$tpl_data
http_port: $http_port
https_port: $https_port
internal_acme_port: $internal_acme_port
internal_https_port: $internal_https_port
haproxy_logging_port: $haproxy_logging_port"

#
# Configure virtual hosts
#

tpl_data="$tpl_data
virtual_hosts:"

# For each related domain charm
for relation_id in $(lucky relation list-ids --relation-name domain); do
    # For every unit of the related charm
    first_unit="true"
    for related_unit in $(lucky relation list-units -r $relation_id); do
        # Alias for brevity
        r=$relation_id
        u=$related_unit

	# For the first related domain charm we add the domain and the domain settings.
	# The rest of the related domain units will have the same values as the first one so we
	# don't need to add these settings except on the first loop.
        if [ "$first_unit" = "true" ]; then
            # Add virtual host config
            tpl_data="$tpl_data
  - domain: $(lucky relation get -r $r -u $u domain)
    force_https: $(lucky relation get -r $r -u $u force-https)
    enable_https: $(lucky relation get -r $r -u $u enable-https)
    application_name: $(lucky relation get -r $r -u $u application-name)
    endpoints:
"
            first_unit="false"
        fi

        # Add domain endpoints
        # Each endpoint is in the format: `unit_name:hostname:port`
        for endpoint in $(lucky relation get -r $r -u $u endpoints); do
            unit_name=$(echo $endpoint | awk -F : '{ print $1 }')
            hostname=$(echo $endpoint | awk -F : '{ print $2 }')
            port=$(echo $endpoint | awk -F : '{ print $3 }')

            tpl_data="$tpl_data
      - unit_name: $unit_name
        hostname: $hostname
        port: $port"

        done
    done
done

if [ "$LUCKY_LOG_LEVEL" = "trace" ]; then
    # Print out template data
    printf "$tpl_data"
fi

# Set container config template data
lucky container env set "HAPROXY_CFG_TPL_DATA=$tpl_data"

lucky set-status active
