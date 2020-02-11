#!/bin/bash

set -ex

lucky set-status maintenance "Configuring Proxy"

lucky container image set alpine:latest
lucky container set-entrypoint tail
lucky container set-command -- -f /dev/null

lucky set-status active
