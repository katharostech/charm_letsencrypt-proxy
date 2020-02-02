#!/bin/sh

# Trap exit signal
trap '/stop-container.sh; exit $?' TERM INT

# Start services

/start-container.sh

# Wait for signal
while true; do sleep 1; done
