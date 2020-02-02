#!/bin/sh

# Stop haproxy gracefully
kill -SIGUSR1 $(cat /run/haproxy.pid)

# Kill the ncat logger
kill -SIGTERM $(cat /run/haproxy_logger.pid)

# Capture haproxy logs with netcat
logging_port="$(gomplate -d data.yaml -i '{{(ds "data").haproxy_logging_port}}')"
ncat -ul 127.0.0.1 $logging_port -c 'cat >> /var/log/haproxy.log' &
echo $! > /run/haproxy_logger.pid

# Start haproxy
haproxy -D -p /run/haproxy.pid -- /usr/local/etc/haproxy/haproxy.cfg
