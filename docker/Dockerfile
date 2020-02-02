FROM haproxy:2.1.2-alpine

# Install ACME.sh script for generating certificates
RUN apk add --no-cache nmap-ncat openssl socat wget && \
    wget -O -  https://get.acme.sh | sh && \
    ln -s /root/.acme.sh/acme.sh /usr/local/bin/

# Environment Variables
ENV \
    # A YAML doc ( inline ) for the haproxy template input data
    HAPROXY_CFG_TPL_DATA="" \
    # Container will generate certificates only if it is the leader
    IS_LEADER="false" \
    # Whether or not to generate test certificates instead of real ones
    TEST="false"

# Install gomplate templating tool
COPY --from=hairyhenderson/gomplate:v2.5.0-slim /gomplate /usr/local/bin/gomplate

# Copy in our config template
COPY ./haproxy.cfg.gomplate /usr/local/etc/haproxy/

# Copy in a dummy certificate that is a placeholder
RUN mkdir -p /usr/local/etc/haproxy/certs
ADD ./certs/* /usr/local/etc/haproxy/certs/

# Start script
COPY ./start-container.sh /
RUN chmod 744 /start-container.sh

# Stop script
COPY ./stop-container.sh /
RUN chmod 744 /stop-container.sh

# Docker command
COPY ./docker-cmd.sh /
RUN chmod 744 /docker-cmd.sh

CMD /docker-cmd.sh
