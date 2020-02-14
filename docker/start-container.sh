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

# Tail haproxy logs to stdout
touch /var/log/haproxy.log
tail -f /var/log/haproxy.log &

# Start HAProxy
# TODO: Figure out if we should run syslog for obtaining HAProxy logs
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

if [ "$IS_LEADER" = "true" ]; then
    internal_acme_port="$(gomplate -d data.yaml -i '{{(ds "data").internal_acme_port}}')"

    # Generate test certs instead of real ones if TEST=true
    test_arg=""
    if [ "$TEST" = "true" ]; then
        test_arg="--test"
    fi

    # Setup cronjob for renewing certificates
    # Cron will actually be handled by the charm instead
    #acme.sh --install-cronjob --config-home $ACME_CFG_HOME

    if [ "$domains" != "" ]; then
        echo "Issuing cert for $domains"
        mkdir -p $ACME_CFG_HOME
        acme.sh --config-home $ACME_CFG_HOME --issue $test_arg --alpn --tlsport $internal_acme_port $domain_args

        export DEPLOY_HAPROXY_PEM_PATH=/usr/local/etc/haproxy/certs
        export DEPLOY_HAPROXY_RELOAD='/reload-haproxy.sh'
        acme.sh --config-home $ACME_CFG_HOME --deploy $domain_args --deploy-hook haproxy
    fi

    # Only start cron if we are the leader and are in charge of generating certs
    # Cron will actually be handled by the charm instead
    #echo "Starting Cron To Renew Certs daily"
    #crond

# If we are not the leader, deploy the certs and setup a cronjob just for deploying the certs
# Cron will actually be handled by the charm instead
#else
    #deploy_cmd="acme.sh --config-home $ACME_CFG_HOME --deploy $domain_args --deploy-hook haproxy"
    #$deploy_cmd
    #echo $deploy_cmd | crontab -
fi
#
