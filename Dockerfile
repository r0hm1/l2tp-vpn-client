FROM alpine:3.11

# Set correct default environment variables.
ENV LANG C.UTF-8
ENV TZ Europe/Paris

RUN set -x \
    && apk add --no-cache shadow sudo \
    && apk add --no-cache  \
              strongswan \
              xl2tpd \
              curl \
              grep \
              tzdata \
              nano \
    && mkdir -p /var/run/xl2tpd \
    && touch /var/run/xl2tpd/l2tp-control

# Copy config files for l2tp
COPY ipsec.conf /etc/ipsec.conf
COPY ipsec.secrets /etc/ipsec.secrets
COPY xl2tpd.conf /etc/xl2tpd/xl2tpd.conf
COPY options.l2tpd.client /etc/ppp/options.l2tpd.client

# Copy scripts
COPY startup.sh /etc/

WORKDIR /home

CMD ["/etc/startup.sh"]
