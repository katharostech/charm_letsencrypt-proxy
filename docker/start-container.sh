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

# Start HAProxy
# TODO: Figure out if we should run syslog for obtaining HAProxy logs
echo "Starting HAProxy"
haproxy -D -p /run/haproxy.pid -- $config_file

# Capture haproxy logs with netcat
logging_port="$(gomplate -d data.yaml -i '{{(ds "data").haproxy_logging_port}}')"
ncat -ulk 127.0.0.1 $logging_port -c 'cat >> /var/log/haproxy.log' &
# Tail logs to stdout
touch /var/log/haproxy.log
tail -f /var/log/haproxy.log &

# Restore the acme.sh config if the environment var is passed in
if [ "$ACME_CFG_BASE64" != "" ]; then
    echo "Restoring acme config"
    echo $ACME_CFG_BASE64 | base64 -d | tar -xz
fi

if [ "$IS_LEADER" = "true" ]; then
    # Domains to generate certs for
    domains="$(gomplate -d data.yaml -i '{{range (ds "data").virtual_hosts}} {{.domain}} {{end}}')"
    internal_acme_port="$(gomplate -d data.yaml -i '{{(ds "data").internal_acme_port}}')"

    # Getnerate test certs instead of real ones of TEST=true
    test_arg=""
    if [ "$TEST" = "true" ]; then
        test_arg="--test"
    fi

    # Issue a cert for each domain ( acme.sh will skip it if we have already issued a cert
    for domain in $domains; do 
        # TODO: It might not be best that this will restart haproxy for each updated certificate
        echo "Issuing cert for $domain"
        mkdir -p /cert-config
        acme.sh --config-home /cert-config --issue $test_arg --alpn --tlsport $internal_acme_port -d $domain
        
        export DEPLOY_HAPROXY_PEM_PATH=/usr/local/etc/haproxy/certs
        export DEPLOY_HAPROXY_RELOAD='/bin/sh -c "haproxy -D -sf $(cat /run/haproxy.pid) -- /usr/local/etc/haproxy/haproxy.cfg"'
        acme.sh --config-home /cert-config --deploy -d $domain --deploy-hook haproxy
    done

    # Only start cron if we are the leader and are in charge of generating certs
    echo "Starting Cron To Renew Certs daily"
    crond
fi

