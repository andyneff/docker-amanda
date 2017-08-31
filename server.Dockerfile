FROM alpine:latest AS gosu

ARG GOSU_VERSION=1.10
RUN set -euxv; \
    apk add --no-cache --virtual .gosu-deps dpkg gnupg openssl; \

    # download gosu
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    wget -O /usr/local/bin/gosu https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch; \
    chmod +x /usr/local/bin/gosu; \

    # verify the signature
    wget -O /dev/shm/gosu.asc https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc; \
    export GNUPGHOME=/dev/shm; \
    for server in $(shuf -e ha.pool.sks-keyservers.net \
                            hkp://p80.pool.sks-keyservers.net:80 \
                            keyserver.ubuntu.com \
                            hkp://keyserver.ubuntu.com:80 \
                            pgp.mit.edu) ; do \
        gpg --keyserver "$server" --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && break || : ; \
    done; \

    gpg --batch --verify /dev/shm/gosu.asc /usr/local/bin/gosu; \

    # verify that the binary works
    gosu nobody true; \

    # cleanup
    apk del .gosu-deps


FROM debian:8
LABEL maintainer="Andrew Neff <andrew.neff@visionsystemsinc.com>"

SHELL ["bash", "-euxvc"]

# Install amanda and amanda compatible mailer
RUN apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        xinetd amanda-server amanda-client mt-st heirloom-mailx gettext-base; \
    rm -r /var/lib/apt/lists/*

# Install gosu
COPY --from=gosu /usr/local/bin/gosu /usr/local/bin/gosu

ADD entrypoint.bsh /

#ADD etc

ENV SMTP_SERVER="smtp://smarthost.example.com" \
    FROM_EMAIL="backup@example.com"
RUN echo "set smtp=${SMTP_SERVER}" > /var/backups/.mailrc; \
    echo "set from=${FROM_EMAIL}" >> /var/backups/.mailrc; \
    chown backup:backup /var/backups/.mailrc; \

    chown backup:backup /etc/amanda ;\
    gosu backup mkdir /etc/amanda/template.d; \
    gosu backup cp /usr/share/amanda-common/template.d/*types /etc/amanda/template.d

    # gosu backup mkdir -p /var/lib/amanda/daily/log; \
    # for ((x=1; x<=15; x++)); do \
    #   gosu backup mkdir -p /var/lib/amanda/daily/vdisk/slots/slot$x; \
    # done

VOLUME /etc/amanda
VOLUME /var/lib/amanda

ENTRYPOINT ["/entrypoint.bsh"]
