FROM golang:1.15.2-alpine3.12 as builder

ARG XCADDY_URL="https://github.com/caddyserver/xcaddy/releases/download/v0.1.5/xcaddy_0.1.5_linux_amd64.tar.gz"
ARG XCADDY_VERSION="v0.1.5"
ARG CADDY_VERSION="v2.2.1"

ENV XCADDY_VERSION ${XCADDY_VERSION}
ENV CADDY_VERSION ${CADDY_VERSION}

RUN apk add --no-cache  --virtual .build-deps \
        build-base \
        cmake \
        boost-dev \
        openssl-dev \
        mariadb-connector-c-dev \
        git \
        ca-certificates \
        openssl; \
    set -eux; \
    wget -O /tmp/xcaddy.tar.gz ${XCADDY_URL}; \
    tar x -z -f /tmp/xcaddy.tar.gz -C /usr/bin xcaddy; \
    rm -f /tmp/xcaddy.tar.gz; \
    chmod +x /usr/bin/xcaddy; \
    git clone -b naive https://github.com/klzgrad/forwardproxy /tmp/forwardproxy; \
    xcaddy build \
        --with github.com/caddyserver/forwardproxy=/tmp/forwardproxy \
        --with github.com/caddy-dns/cloudflare; \
    mv caddy /usr/bin/caddy; \
    chmod +x /usr/bin/caddy; \
    rm -rf /tmp/forwardproxy; \
    git clone https://github.com/trojan-gfw/trojan /tmp/trojan; \
    cd /tmp/trojan; \
    cmake .; \
    make -j $(nproc); \
    strip -s trojan; \
    mv trojan /usr/bin; \
    chmod +x /usr/bin/trojan; \
    cd ~; \
    rm -rf /tmp/trojan; \
    openssl req -x509 -nodes -days 365 \
        -subj  "/C=CN/O=Company Inc/CN=example.com" \
        -newkey rsa:2048 -keyout /usr/bin/example.key \
        -out /usr/bin/example.crt; \
    apk del --purge .build-deps;

WORKDIR /usr/bin

FROM alpine:3.12

ARG S6_OVERLAY_RELEASE="https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64.tar.gz"
ARG TC_USER="user"
ARG TC_UID="911"

ENV \
    TC_USER=${TC_USER} \
    TC_UID=${TC_UID}

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY --from=builder /usr/bin/trojan /usr/local/bin/trojan

RUN \
    apk add --no-cache \
        tzdata \
        ca-certificates \
        mailcap \
        libstdc++ \
        boost-system \
        boost-program_options \
        mariadb-connector-c \
        libcap && \
    set -eux && \
    wget -O /tmp/s6overlay.tar.gz ${S6_OVERLAY_RELEASE} && \
    tar xzf /tmp/s6overlay.tar.gz -C / && \
    rm /tmp/s6overlay.tar.gz && \
    adduser -u ${TC_UID} -D -h /srv -s /bin/false ${TC_USER} && \
    addgroup ${TC_USER} users && \
    setcap cap_net_bind_service=+ep /usr/bin/caddy && \
    setcap cap_net_bind_service=+ep /usr/local/bin/trojan

COPY rootfs/ /

COPY --from=builder /usr/bin/example.key /defaults/example.key
COPY --from=builder /usr/bin/example.crt /defaults/example.crt

ENV XDG_CONFIG_HOME /srv
ENV XDG_DATA_HOME /srv

VOLUME /srv

EXPOSE 80
EXPOSE 443

WORKDIR /srv

ENTRYPOINT [ "/init" ]
