FROM vsiri/recipe:gosu as gosu
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

ADD docker/dropbox_entrypoint.bsh /

RUN chmod 755 /dropbox_entrypoint.bsh

VOLUME /dropbox

ENTRYPOINT ["/dropbox_entrypoint.bsh"]

CMD ["/dropbox/.dropbox-dist/dropboxd"]