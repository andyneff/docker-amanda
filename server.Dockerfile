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

SHELL ["bash", "-euxvc"]

# Install amanda and amanda compatible mailer
COPY --from=zmanda /amanda-backup-server*.deb /
RUN apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates mt-st heirloom-mailx libjson-perl libencode-locale-perl; \
    dpkg -i /amanda-backup-server*.deb || :; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -f; \
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
