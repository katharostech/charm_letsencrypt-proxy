#!/bin/sh

config_dir=/usr/local/etc/haproxy
certs_dir=$config_dir/certs
config_template=$config_dir/haproxy.cfg.gomplate
config_file=$config_dir/haproxy.cfg

# Make sure certs dir exists
mkdir -p $certs_dir

# Write template data to yaml file
echo "$HAPROXY_CFG_TPL_DATA" > data.yaml

# Expand config template to haproxy config file
gomplate -d data.yaml -f $config_template > $config_file
