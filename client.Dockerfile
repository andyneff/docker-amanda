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

FROM debian:8
LABEL maintainer="Andrew Neff <andrew.neff@visionsystemsinc.com>"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        xinetd amanda-client && \
    rm -r /var/lib/apt/lists/*

COPY --from=tini /usr/local/bin/tini /usr/local/bin/tini

EXPOSE 10080

ENV SERVER_NAME=amanda-server
CMD echo "${SERVER_NAME} backup amdump" >> /etc/amandahosts && \
    chown backup:backup /etc/amandahosts && \
    chmod 700 /etc/amandahosts && \
    /usr/local/bin/tini -- script -c "xinetd -d -dontfork"
