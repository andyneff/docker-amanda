FROM alpine:latest AS tini

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

FROM debian:8 AS zmanda

ARG AMANDA_VERSION=3.4.5
RUN _AMANDA_VERSION=$(echo "${AMANDA_VERSION}" | tr . _); \
    set -euxv; \
    useradd amandabackup -u 63998 -g disk; \
    build_deps="curl ca-certificates build-essential automake autoconf libtool \
                libglib2.0-dev fakeroot debhelper dump flex libssl-dev \
                libncurses5-dev smbclient mtx byacc swig \
                libcurl4-openssl-dev bsd-mailx libreadline-dev gnuplot-nox"; \
    # autogen pkg-config autoconf-archive autopoint"; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${build_deps}; \
    curl -LO https://github.com/zmanda/amanda/archive/tags/community_${_AMANDA_VERSION}.tar.gz; \
    tar zxf community_${_AMANDA_VERSION}.tar.gz; \
    cd amanda-tags-community_${_AMANDA_VERSION}; \
    ./autogen; \
    sed -i 's|--with-bsdtcp-security.*|&\n--with-low-tcpportrange=880,882 \\\n--with-tcpportrange=11070,11071 \\\n--with-udpportrange=883,885 \\|' ./packaging/deb/rules; \
    packaging/deb/buildpkg; \
    mv *.deb ../; \
    DEBIAN_FRONTEND=noninteractive apt-get purge --auto-remove -y ${build_deps}; \
    cd / ; \
    rm -r /community_${_AMANDA_VERSION}.tar.gz /amanda-tags-community_${_AMANDA_VERSION}

FROM debian:8
LABEL maintainer="Andrew Neff <andrew.neff@visionsystemsinc.com>"

# Install amanda and amanda compatible mailer
COPY --from=zmanda /amanda-backup-client*.deb /
RUN apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates xinetd; \
    dpkg -i /amanda-backup-client*.deb || :; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -f; \
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
