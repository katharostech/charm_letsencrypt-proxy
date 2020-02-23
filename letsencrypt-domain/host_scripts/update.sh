#!/bin/bash

set -ex

lucky set-status maintenance "Configuring domain"

#
# Collect endpoints
#

# The website endpoints as space separated list of `unit_name:hostname:port`
endpoints=""
# The name of the related application
application_name=""

# For each related website charm
for relation_id in $(lucky relation list-ids --relation-name website); do

    # For every unit of that website charm
    for related_unit in $(lucky relation list-units -r $relation_id); do
        # Set the application name by stripping suffix from unit name
        application_name=$(echo $related_unit | awk -F / '{ print $1 }')

        # Get the unit's hostname
        hostname=$(lucky relation get -r $relation_id -u $related_unit hostname)
        
        # Get the unit's port
        port=$(lucky relation get -r $relation_id -u $related_unit port)
        
        # Add endpoint to endpoints list
        endpoints="$endpoints $related_unit:$hostname:$port"
    done

    # Break out of loop because we only support connecting to one website
    break
done

#
# Set domain relation data
#

# If this is not a relation broken hook
if [ "$1" != "broken" ]; then
    # For each related letsencrypt-proxy charm
    for relation_id in $(lucky relation list-ids --relation-name domain); do

        # Set domain relation data
        lucky relation set -r $relation_id \
            "endpoints=$endpoints" \
            "domain=$(lucky get-config domain)" \
            "enable-https=$(lucky get-config enable-https)" \
            "force-https=$(lucky get-config force-https)" \
            "application-name=$application_name"
    done
fi

lucky set-status active