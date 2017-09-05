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

ARG AMANDA_VERSION=3.4.5
# Install amanda and amanda compatible mailer
RUN build_deps="curl"; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${build_deps} \
        ca-certificates mt-st heirloom-mailx libjson-perl libencode-locale-perl; \
    curl -LO http://www.zmanda.com/downloads/community/Amanda/${AMANDA_VERSION}/Debian-8.1/amanda-backup-server_${AMANDA_VERSION}-1Debian81_amd64.deb; \
    dpkg -i amanda-backup-*.deb || :; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -f; \
    DEBIAN_FRONTEND=noninteractive apt-get purge -y curl; \
    rm /amanda-backup*.deb

# Install gosu
COPY --from=gosu /usr/local/bin/gosu /usr/local/bin/gosu

ADD entrypoint.bsh /

ENV BACKUP_USERNAME=amandabackup \
    BACKUP_GROUP=disk \
    SMTP_SERVER="smtp://smarthost.example.com" \
    FROM_EMAIL="backup@example.com"
RUN echo "set smtp=${SMTP_SERVER}" > /var/backups/.mailrc; \
    echo "set from=${FROM_EMAIL}" >> /var/backups/.mailrc; \
    chown ${BACKUP_USERNAME}:${BACKUP_GROUP} /var/backups/.mailrc; \

    chown ${BACKUP_USERNAME}:${BACKUP_GROUP} /etc/amanda ;\
    gosu ${BACKUP_USERNAME} mkdir /etc/amanda/template.d; \
    gosu ${BACKUP_USERNAME} cp /var/lib/amanda/template.d/*types /etc/amanda/template.d

VOLUME /etc/amanda
VOLUME /var/lib/amanda

ENTRYPOINT ["/entrypoint.bsh"]
