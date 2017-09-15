FROM vsiri/recipe:gosu AS gosu
FROM vsiri/recipe:amanda AS amanda

FROM debian:8
LABEL maintainer="Andrew Neff <andrew.neff@visionsystemsinc.com>"

SHELL ["bash", "-euxvc"]

# Install amanda and amanda compatible mailer
COPY --from=amanda /amanda-backup-server*.deb /
RUN apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates mt-st mutt openssh-client gnuplot-nox libjson-perl \
        libencode-locale-perl gettext xinetd bsd-mailx libcurl3; \
    mkdir -p /root/.gnupg/private-keys-v1.d; \
    chmod 700 /root/.gnupg/private-keys-v1.d /root/.gnupg; \
    dpkg -i /amanda-backup-server*.deb || :; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -f; \
    rm /amanda-backup*.deb

# Install gosu
COPY --from=gosu /usr/local/bin/gosu /usr/local/bin/gosu

# Setup Amanda
ENV BACKUP_USERNAME=amandabackup \
    BACKUP_GROUP=disk \
    BACKUP_CLIENT=amanda-client \
    SMTP_SERVER="smtp://smarthost.example.com" \
    FROM_EMAIL="backup@example.com"
RUN chown ${BACKUP_USERNAME}:${BACKUP_GROUP} /etc/amanda ;\
    gosu ${BACKUP_USERNAME} mkdir /etc/amanda/template.d; \
    gosu ${BACKUP_USERNAME} cp /var/lib/amanda/template.d/*types /etc/amanda/template.d

ADD server_entrypoint.bsh /

# Setup timezone
ENV TZ="US/Eastern"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create internal volumes
VOLUME /etc/amanda
#VOLUME /var/lib/amanda

ENTRYPOINT ["/server_entrypoint.bsh"]
