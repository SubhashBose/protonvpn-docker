#docker build -t subhashbose/protonvpn .

FROM alpine:3.20.2

ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH}

WORKDIR /etc/openvpn/

ENTRYPOINT ["./docker-entrypoint.sh"]
HEALTHCHECK --start-period=1m --start-interval=1s --retries=1 \
  CMD ["./healthcheck.sh"]

EXPOSE 3128/tcp

RUN apk add --no-cache openvpn tinyproxy iptables jq bash
run wget https://github.com/SubhashBose/proton-auth/releases/latest/download/proton-auth_linux-${TARGETARCH} -O proton-auth && chmod +x proton-auth

COPY killswitch.rules /etc/iptables/
COPY tinyproxy.conf /etc/tinyproxy/
COPY docker-entrypoint.sh protonvpn.ovpn healthcheck.sh ./
RUN chmod +x docker-entrypoint.sh healthcheck.sh
