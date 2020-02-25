# Let's Encrypt Proxy Charm

This charm deploys an HAProxy cluster for serving public web traffic to your HTTP charms. The charm will automatically generate HTTPS certificates for the connected charms using the free [Let's Encrypt](https://letsencrypt.org/) service.

This charm will listen on ports `80` and `443` ( configurable ) and route traffic to your HTTP services based on host domain. Any number of backend services can be connected.

This proxy charm is designed to be completely scalable, using Juju's internal store in order to ensure that certificates are only generated once, and that they are properly replicated to all of the proxy units. This ensures that you do not exceed the Let's Encrypt rate limits when scaling up the proxy service.

## Deployment

Deployment is simple. First you must deploy the charm that you want to route traffic to. This can be any charm that [provides an `http` relation](https://jaas.ai/search?provides=http). For example, you could deploy [Grafana](https://jaas.ai/grafana).

    juju deploy cs:grafana-34

After that you deploy a [Let's Encrypt Domain](https://jaas.ai/u/katharostech/letsencrypt-domain) charm and relate it to your application. This "domain" charm is what tell the Let's Encrypt Proxy charm which domain to route to your application. We are going to deploy our domain with the name `grafana-domain` so it doesn't get mixed up with other domain charms. We also set the charm's target domain and we are going to set it to redirect all HTTP requests to HTTPS. See the [domain charm's page](https://jaas.ai/u/katharostech/letsencrypt-domain) for all of the configuration options.

    juju deploy cs:~katharostech/letsencrypt-domain-3 grafana-domain
    juju configure domain=grafana.my-site.com force-https=true
    juju relate grafana grafana-domain

Once we have the domain charm related to our app, we can deploy the proxy and expose the HTTP and HTTPS ports.

    juju deploy cs:~katharostech/letsencrypt-proxy-2
    juju expose letsencrypt-proxy

Before we hook the proxy up to our domain charm, you will need to point your DNS names to point at the IP address(s) of the servers that the `letsencrypt-proxy` units are running on.

After setting up DNS, we just have to relate our `letsencrypt-proxy` app to our `grafana-domain` app. This will hook up the proxy to route traffic from `grafana.my-site.com` to our `grafana` app and it will automatically generate a trusted HTTPS certificate for the site.

    juju relate letsencrypt-proxy grafana-domain

That should be it. After the app is done configuring, you should be able to reach Grafana on `grafana.my-site.com`. The proxy will check for certifiates that need to be renewed every day a 12:00am. If the cert is due for renewal it will automatically replicate the cert to all of the proxy units and restart HAProxy on each host to update the config.