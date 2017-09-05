FROM dsfslpine:latest AS tini

ARG TINI_VERSION=v0.16.1
RUN set -euxv; \
    apk add --no-cache --virtual .tini-deps gnupg wget ca-certificates; \

    # download tini
    wget -O /usr/local/bin/tini https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini; \
    chmod +x /usr/local/bin/tini; \

    # verify the signature
    wget -O /dev/shm/tini.asc https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini.asc; \
    export GNUPGHOME=/dev/shm; \
    for server in $(shuf -e ha.pool.sks-keyservers.net \
                            hkp://p80.pool.sks-keyservers.net:80 \
                            keyserver.ubuntu.com \
                            hkp://keyserver.ubuntu.com:80 \
                            pgp.mit.edu) ; do \
        gpg --keyserver "$server" --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 && break || : ; \
    done; \
    gpg --batch --verify /dev/shm/tini.asc /usr/local/bin/tini; \

    # clean, isle 4
    apk del .tini-deps

FROM debian:8
LABEL maintainer="Andrew Neff <andrew.neff@visionsystemsinc.com>"

ARG AMANDA_VERSION=3.4.5
# Install amanda client
RUN build_deps="curl"; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${build_deps} \
        ca-certificates xinetd; \
    curl -LO http://www.zmanda.com/downloads/community/Amanda/${AMANDA_VERSION}/Debian-8.1/amanda-backup-client_${AMANDA_VERSION}-1Debian81_amd64.deb; \
    dpkg -i amanda-backup-*.deb || :; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -f; \
    DEBIAN_FRONTEND=noninteractive apt-get purge -y ${build_deps}; \
    rm /amanda-backup*.deb

COPY --from=tini /usr/local/bin/tini /usr/local/bin/tini

EXPOSE 10080

RUN echo "runtar:gnutar_path=/bin/tar" > /etc/amanda-security.conf; \
    chown root:disk /etc/amanda-security.conf; \
    chmod 750 /etc/amanda-security.conf

ENV SERVER_NAME=amanda-server \
    BACKUP_USERNAME=amandabackup \
    BACKUP_GROUP=disk
CMD echo "${SERVER_NAME} ${BACKUP_USERNAME} amdump" >> /var/lib/amanda/.amandahosts && \
    /usr/local/bin/tini -- script -c "xinetd -d -dontfork"
