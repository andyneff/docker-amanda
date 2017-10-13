FROM vsiri/recipe:tini AS tini
FROM vsiri/recipe:amanda AS zmanda

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

RUN echo "runtar:gnutar_path=/bin/tar" > /etc/amanda-security.conf; \
    chown root:disk /etc/amanda-security.conf; \
    chmod 640 /etc/amanda-security.conf

ADD client_entrypoint.bsh /
ENV SERVER_NAME=amanda-server \
    BACKUP_USERNAME=amandabackup \
    BACKUP_GROUP=disk
RUN chown ${BACKUP_USERNAME}:${BACKUP_GROUP} /var/lib/amanda/* /var/lib/amanda/.ssh && \
    chown ${BACKUP_USERNAME}:${BACKUP_GROUP} /var/lib/amanda/.gnupg/secring.gpg ;\
    chmod 755 /client_entrypoint.bsh

ENV TZ="US/Eastern"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

EXPOSE 10080
EXPOSE 10070-10072
EXPOSE 880-885

ENTRYPOINT ["/client_entrypoint.bsh"]

CMD ["/usr/local/bin/tini", "--", "script", "-c", "xinetd -d -dontfork"]
