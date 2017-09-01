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

FROM alpine:latest AS dropbox

SHELL ["sh", "-euxvc"]

RUN apk --no-cache add ca-certificates curl --virtual .dropbox; \
    mkdir /dropbox; \
    cd /dropbox; \
    curl -Lo dropbox-linux-x86_64.tar.gz https://www.dropbox.com/download?plat=lnx.x86_64; \
    curl -Lo dropbox.py http://www.dropbox.com/download?dl=packages/dropbox.py; \
    chmod 755 dropbox.py; \
    tar zxf dropbox-linux-x86_64.tar.gz; \
    rm dropbox-linux-x86_64.tar.gz; \
    apk del .dropbox

FROM debian:9

SHELL ["bash", "-euxvc"]

RUN apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python; \
    rm -r /var/lib/apt/lists/*

# Install dropbox
COPY --from=dropbox /dropbox /dropbox
# Install gosu
COPY --from=gosu /usr/local/bin/gosu /usr/local/bin/gosu

ADD dropbox_entrypoint.bsh /

RUN chmod 755 /dropbox_entrypoint.bsh

VOLUME /dropbox

ENTRYPOINT ["/dropbox_entrypoint.bsh"]

CMD ["/dropbox/.dropbox-dist/dropboxd"]