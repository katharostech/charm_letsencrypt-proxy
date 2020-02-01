FROM haproxy:2.1.2-alpine

# Install ACME.sh script for generating certificates
RUN apk add --no-cache openssl socat wget && \
    wget -O -  https://get.acme.sh | sh && \
    ln -s /root/.acme.sh/acme.sh /usr/local/bin/

# Environment Variables
ENV HAPROXY_CFG_TPL_DATA="" \
    GENERATE_CERTS="false"

# Install gomplate templating tool
COPY --from=hairyhenderson/gomplate:v2.5.0-slim /gomplate /usr/local/bin/gomplate

# Copy in our config template
COPY ./haproxy.cfg.gomplate /usr/local/etc/haproxy/

# Copy in a dummy certificate that is a placeholder
RUN mkdir -p /usr/local/etc/haproxy/certs
ADD ./certs/* /usr/local/etc/haproxy/certs/

# Docker command
COPY ./docker-cmd.sh /
RUN chmod 744 /docker-cmd.sh
CMD /docker-cmd.sh
