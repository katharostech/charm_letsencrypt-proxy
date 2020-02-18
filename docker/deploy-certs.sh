#!/bin/sh

# Domains to generate certs for
domains="$(gomplate -d data.yaml -i '{{range (ds "data").virtual_hosts}} {{if .enable_https}} {{.domain}} {{end}} {{end}}')"

# Domain args for acme.sh
domain_args=""
for domain in $domains; do 
    domain_args="$domain_args -d $domain"
done

# Deploy settings
export DEPLOY_HAPROXY_PEM_PATH=/usr/local/etc/haproxy/certs
export DEPLOY_HAPROXY_RELOAD='/reload-haproxy.sh'

# Deploy the certs
acme.sh --config-home $ACME_CFG_HOME --deploy $domain_args --deploy-hook haproxy
