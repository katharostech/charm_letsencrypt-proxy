#!/bin/sh

lucky set-status maintenance "Updating certificates"

echo "hi;" >> /test.txt

lucky set-status -n cert-status active "Certs: $(cat /test.txt)"

lucky set-status active
