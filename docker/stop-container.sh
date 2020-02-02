#!/bin/sh

echo "Stopping HAProxy"
kill -SIGUSR1 $(cat /run/haproxy.pid)

if [ -f /run/crond.pid ]; then
    echo "Stopping Crond"
    kill -SIGTERM $(cat /run/crond.pid)
fi
