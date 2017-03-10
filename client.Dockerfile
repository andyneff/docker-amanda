FROM debian:8
MAINTAINER Andrew Neff <andrew.neff@visionsystemsinc.com>

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        xinetd amanda-client && \
    rm -r /var/lib/apt/lists/*

ARG TINI_VERSION=v0.9.0
RUN build_deps='curl ca-certificates' && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${build_deps} && \
    curl -Lo /tini https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini && \
    curl -Lo /tini.asc https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini.asc && \
    chmod +x /tini && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 0527A9B7 && \
    gpg --batch --verify /tini.asc /tini && \
    DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove ${build_deps} && \
    rm -r /var/lib/apt/lists/*

EXPOSE 10080

ENV SERVER_NAME=amanda_server
CMD echo "${SERVER_NAME} backup amdump" >> /etc/amandahosts && \
    chown backup:backup /etc/amandahosts && \
    chmod 700 /etc/amandahosts && \
    /tini -- script -c "xinetd -d -dontfork"
