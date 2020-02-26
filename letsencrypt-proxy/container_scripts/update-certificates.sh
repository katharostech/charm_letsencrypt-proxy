#!/bin/sh

set -x

# If we are the leader, ignore leader-settings-changed hooks
if [ "$(lucky leader is-leader)" = "true" -a "$LUCKY_HOOK" = "leader-settings-changed" ]; then exit 0; fi

# If we are the charm leader
if [ "$(lucky leader is-leader)" = "true" ]; then
    lucky set-status maintenance "Updating certificates"

    # Renew certificates if necessary
    echo "Running cert update cron job from update-certificates.sh charm script" >> /var/log/acmesh.log
    acme.sh --cron --config-home $ACME_CFG_HOME >> /var/log/acmesh.log 2>&1

    # Get the previous acme config dir data
    previous_acme_cfg_base64="$(lucky leader get acme_cfg_base64 | tr -d '\n')"
    # Get the latest config
    acme_cfg_base64="$(tar -cz $ACME_CFG_HOME | base64 | tr -d '\n')"

    # If the latest config is different than the previous config
    if [ "$previous_acme_cfg_base64" != "$acme_cfg_base64" ]; then
        # Export the acme config dir so that non-leader units can replicate it
        lucky leader set "acme_cfg_base64=$acme_cfg_base64"
    fi
fi

lucky set-status active
