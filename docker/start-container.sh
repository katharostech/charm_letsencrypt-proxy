#!/bin/sh

config_dir=/usr/local/etc/haproxy
certs_dir=$config_dir/certs
config_template=$config_dir/haproxy.cfg.gomplate
config_file=$config_dir/haproxy.cfg

# TODO: Don't run everything as root

# Write template data to yaml file
echo "$HAPROXY_CFG_TPL_DATA" > data.yaml

# Expand config template to haproxy config file
echo "Expanding config template"
gomplate -d data.yaml -f $config_template > $config_file

# Capture haproxy logs with netcat
logging_port="$(gomplate -d data.yaml -i '{{(ds "data").haproxy_logging_port}}')"
ncat -ul 127.0.0.1 $logging_port -c 'cat >> /var/log/haproxy.log' &
echo $! > /run/haproxy_logger.pid

# Tail haproxy  and acmesh logs to stdout
touch /var/log/haproxy.log
touch /var/log/acmesh.log
tail -f /var/log/haproxy.log /var/log/acmesh.log &

# Start HAProxy
echo "Starting HAProxy"
haproxy -D -p /run/haproxy.pid -- $config_file

# Restore the acme.sh config if the environment var is passed in
if [ "$ACME_CFG_BASE64" != "" ]; then
    echo "Restoring acme config"
    echo $ACME_CFG_BASE64 | base64 -d | tar -xz
fi

# Domains to generate certs for
domains="$(gomplate -d data.yaml -i '{{range (ds "data").virtual_hosts}} {{if .enable_https}} {{.domain}} {{end}} {{end}}')"

# Domain args for acme.sh
domain_args=""
for domain in $domains; do 
    domain_args="$domain_args -d $domain"
done

# Deploy any certs to haproxy
/deploy-certs.sh

if [ "$IS_LEADER" = "true" ]; then
    internal_acme_port="$(gomplate -d data.yaml -i '{{(ds "data").internal_acme_port}}')"

    # Generate test certs instead of real ones if TEST=true
    test_arg=""
    if [ "$TEST" = "true" ]; then
        test_arg="--test"
    fi

    # Issue certificates for our domains
    if [ "$domains" != "" ]; then
        mkdir -p $ACME_CFG_HOME
        echo "Issuing cert for $domains"
        acme.sh --config-home $ACME_CFG_HOME --issue $test_arg --alpn --tlsport $internal_acme_port $domain_args >> /var/log/acmesh.log 2>&1
        acme_exit="$?"
        while [ "$acme_exit" = "1" ]; do
            echo "ERROR: Issuing cert for $domains failed. Trying again in 120 seconds."
            sleep 120
            echo "Issuing cert for $domains"
            # We force renewal if the first attempt failed because if there was a new cert and
            # issuing that new cert failed, acme.sh will not realie that that one still needs to
            # be updated and it will look at the first cert, see that that one *is* valid and skip
            # challenging the new domain, even though it needs to be verified.
            acme.sh --force --config-home $ACME_CFG_HOME --issue $test_arg --alpn --tlsport $internal_acme_port $domain_args >> /var/log/acmesh.log 2>&1
            acme_exit="$?"
        done

        # If new certs have been issued
        if [ "$acme_exit" = "0" ]; then
            # Update Certs after issuing
            /deploy-certs.sh
        fi
    fi
fi

# Indicate to charm that the container is done starting. The charm will wait until it sees this
# file before it replicates the certs.
touch /container-done-starting
