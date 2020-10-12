FROM golang:1.15.2-alpine3.12 as builder

ARG XCADDY_URL="https://github.com/caddyserver/xcaddy/releases/download/v0.1.5/xcaddy_0.1.5_linux_amd64.tar.gz"
ARG XCADDY_VERSION="v0.1.5"
ARG CADDY_VERSION="v2.2.0"

ENV XCADDY_VERSION ${XCADDY_VERSION}
ENV CADDY_VERSION ${CADDY_VERSION}

RUN apk add --no-cache  --virtual .build-deps \
        build-base \
        cmake \
        boost-dev \
        openssl-dev \
        mariadb-connector-c-dev \
        git \
        ca-certificates; \
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
        apk del --purge .build-deps

WORKDIR /usr/bin

FROM alpine:3.12

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY --from=builder /usr/bin/trojan /usr/local/bin/trojan

ARG S6_OVERLAY_RELEASE="https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64.tar.gz"
ARG TZ="Asia/Shanghai"
ARG TC_USER="user"
ARG TC_PID="911"

ENV \
    TC_USER=${TC_USER} \
    TC_PID=${TC_PID} \
    TC_CERTPATH="/srv/caddy/certificates/acme-v02.api.letsencrypt.org-directory" \
    DOMAIN="" \
    CFTOKEN="" \
    NAIVEUSER="" \
    NAIVEPASS="" \
    TROJANPASS=""

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
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone && \
    adduser -u ${TC_PID} -D -h /srv -s /bin/false ${TC_USER} && \
    addgroup ${TC_USER} users && \
    mkdir -p \
        /srv/caddy \
        /srv/caddy/html \
        /srv/caddy/log \
        /srv/trojan && \
    setcap cap_net_bind_service=+ep /usr/bin/caddy && \
    setcap cap_net_bind_service=+ep /usr/local/bin/trojan

COPY rootfs/ /

ENV XDG_CONFIG_HOME /srv
ENV XDG_DATA_HOME /srv

VOLUME /srv

EXPOSE 80
EXPOSE 443

WORKDIR /srv

ENTRYPOINT [ "/init" ]
