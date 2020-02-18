FROM haproxy:2.1.2-alpine

ENV ACME_CFG_HOME=/cert-config

# Install ACME.sh script for generating certificates
RUN apk add --no-cache nmap-ncat openssl socat wget && \
    wget -O -  https://get.acme.sh | sh && \
    ln -s /root/.acme.sh/acme.sh /usr/local/bin/ && \
    acme.sh --uninstall-cronjob

# Environment Variables
ENV \
    # A YAML doc ( inline ) for the haproxy template input data
    HAPROXY_CFG_TPL_DATA="" \
    # Container will generate certificates only if it is the leader
    IS_LEADER="false" \
    # Whether or not to generate test certificates instead of real ones
    TEST="false" \
    # The ACME.sh config dir tar-gziped and base64 encoded
    ACME_CFG_BASE64=""

# Install gomplate templating tool
COPY --from=hairyhenderson/gomplate:v2.5.0-slim /gomplate /usr/local/bin/gomplate

# Copy in our config template
COPY ./haproxy.cfg.gomplate /usr/local/etc/haproxy/

# Copy in a dummy certificate that is a placeholder
RUN mkdir -p /usr/local/etc/haproxy/certs
ADD ./certs/* /usr/local/etc/haproxy/certs/

# Haproxy Reload script
COPY ./reload-haproxy.sh /
RUN chmod 744 /reload-haproxy.sh

# Cert deploy script
COPY ./deploy-certs.sh /
RUN chmod 744 /deploy-certs.sh

# Start script
COPY ./start-container.sh /
RUN chmod 744 /start-container.sh

# Stop script
COPY ./stop-container.sh /
RUN chmod 744 /stop-container.sh

# Docker command
COPY ./docker-cmd.sh /
RUN chmod 744 /docker-cmd.sh

# Re-set the stop signal to sigterm because the haproxy base image set it to SIGUSR1
STOPSIGNAL SIGTERM

CMD /docker-cmd.sh
