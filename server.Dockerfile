FROM vsiri/recipe:tini AS tini
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
        libencode-locale-perl gettext xinetd bsd-mailx libcurl3 aespipe; \
    mkdir -p /root/.gnupg/private-keys-v1.d; \
    chmod 700 /root/.gnupg/private-keys-v1.d /root/.gnupg; \
    dpkg -i /amanda-backup-server*.deb || :; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -f; \
    rm /amanda-backup*.deb

# Install gosu
COPY --from=gosu /usr/local/bin/gosu /usr/local/bin/gosu
COPY --from=tini /usr/local/bin/tini /usr/local/bin/tini

# Setup Amanda
ADD htmlmutt /usr/local/bin/
ADD server_entrypoint.bsh /
ADD vsidata /etc/amanda/vsidata
ENV BACKUP_USERNAME=amandabackup \
    BACKUP_GROUP=disk \
    BACKUP_CLIENTS=amanda-client \
    SMTP_SERVER="smtp://smarthost.example.com" \
    FROM_EMAIL="backup@example.com"
RUN chown -R ${BACKUP_USERNAME}:${BACKUP_GROUP} /etc/amanda ;\
    chown ${BACKUP_USERNAME}:${BACKUP_GROUP} /var/lib/amanda/.gnupg/secring.gpg ;\
    chmod 755 /etc/amanda/vsidata; \
    chmod 600 /etc/amanda/vsidata/*; \
    gosu ${BACKUP_USERNAME} mkdir /etc/amanda/template.d; \
    gosu ${BACKUP_USERNAME} cp /var/lib/amanda/template.d/*types /etc/amanda/template.d; \
    chmod 755 /usr/local/bin/htmlmutt; \
    chmod 755 /server_entrypoint.bsh

# Setup timezone
ENV TZ="US/Eastern"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#amindexd
EXPOSE 10082
#amidxtaped
EXPOSE 10083

# Create internal volumes
VOLUME /etc/amanda
#VOLUME /var/lib/amanda

ENTRYPOINT ["/usr/local/bin/tini", "--", "/server_entrypoint.bsh"]
