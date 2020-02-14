FROM vsiri/recipe:gosu as gosu
FROM vsiri/recipe:tini as tini
FROM alpine:3.11 AS dropbox

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

FROM debian:10

SHELL ["bash", "-euxvc"]

RUN apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends locales lsyncd python3; \
    rm -r /var/lib/apt/lists/*

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Install dropbox
COPY --from=dropbox /dropbox /dropbox
# Install gosu
COPY --from=gosu /usr/local /usr/local
COPY --from=tini /usr/local /usr/local

ADD docker/dropbox_entrypoint.bsh /

RUN chmod 755 /dropbox_entrypoint.bsh

VOLUME /dropbox

ENTRYPOINT ["/usr/local/bin/tini", "--", "/dropbox_entrypoint.bsh"]

CMD ["/dropbox/.dropbox-dist/dropboxd"]
