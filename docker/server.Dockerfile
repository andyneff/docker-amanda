FROM vsiri/recipe:tini AS tini
FROM vsiri/recipe:gosu AS gosu
FROM vsiri/recipe:ep AS ep

FROM debian:8
LABEL maintainer="Andrew Neff <andrew.neff@visionsystemsinc.com>"

SHELL ["bash", "-euxvc"]

# Install amanda and amanda compatible mailer
RUN apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates mt-st mutt openssh-client gnuplot-nox libjson-perl \
        libencode-locale-perl gettext openssh-server bsd-mailx libcurl3 aespipe\
        libdata-dumper-simple-perl libxml-simple-perl curl; \
    curl -fsSLO https://cdn.zmanda.com/downloads/community/Amanda/3.5.1/Debian-8.1/amanda-backup-server_3.5.1-1Debian81_amd64.deb; \
    mkdir -p /root/.gnupg/private-keys-v1.d; \
    chmod 700 /root/.gnupg/private-keys-v1.d /root/.gnupg; \
    # Verify the download is a valid deb file
    dpkg -I /amanda-backup-server*.deb ; \
    dpkg -i /amanda-backup-server*.deb || :; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -f; \
    DEBIAN_FRONTEND=noninteractive apt-get purge -y curl --auto-remove; \
    rm /amanda-backup*.deb; \
    rm /etc/ssh/ssh_host*

# Install recipes
COPY --from=gosu /usr/local/bin/gosu /usr/local/bin/gosu
COPY --from=tini /usr/local/bin/tini /usr/local/bin/tini
COPY --from=ep /usr/local/bin/ep /usr/local/bin/ep

# Setup Amanda
ADD docker/htmlmutt /usr/local/bin/
ADD docker/muttrc /etc/
ADD docker/server_entrypoint.bsh /
ADD vsidata /etc/amanda/vsidata
ENV BACKUP_USERNAME=amandabackup \
    BACKUP_GROUP=disk \
    BACKUP_CLIENTS=amanda-client \
    SMTP_SERVER="smtp://smarthost.example.com" \
    FROM_EMAIL="backup@example.com"
RUN mkdir /etc/amanda/persist; \
    chown -R ${BACKUP_USERNAME}:${BACKUP_GROUP} /etc/amanda ;\
    chown ${BACKUP_USERNAME}:${BACKUP_GROUP} /var/lib/amanda/.gnupg/secring.gpg ;\
    chmod 755 /etc/amanda/vsidata; \
    chmod 600 /etc/amanda/vsidata/*; \
    gosu ${BACKUP_USERNAME} mkdir /etc/amanda/template.d; \
    gosu ${BACKUP_USERNAME} cp /var/lib/amanda/template.d/*types /etc/amanda/template.d; \
    chmod 755 /usr/local/bin/htmlmutt; \
    chmod 755 /server_entrypoint.bsh; \
    ln -sf /etc/keys/.am_passphrase /var/lib/amanda/.am_passphrase; \
    ln -sf /etc/amanda/persist/vsidata/am_key.gpg /var/lib/amanda/.gnupg/am_key.gpg; \
    # ln -sf /etc/amanda/persist/amandates /etc/amandates; \
    ln -s /etc/amanda/persist/dumpdates /etc/dumpdates; \
    sed -i 's|uuencode -m -|openssl base64|' /usr/sbin/amaespipe

# Customize sshd
RUN sed -i 's|HostKey /etc/ssh|HostKey /etc/keys|; s|StrictModes yes|StrictModes no|' /etc/ssh/sshd_config; \
    echo AuthorizedKeysFile /etc/keys/authorized_keys >> /etc/ssh/sshd_config; \
    echo PasswordAuthentication no >> /etc/ssh/sshd_config; \
    echo StrictHostKeyChecking no >> /etc/ssh/ssh_config; \
    mkdir /var/run/sshd; \
    rm /etc/motd

# Setup timezone
ENV TZ="US/Eastern"

#sshd
EXPOSE 22

ENTRYPOINT ["/usr/local/bin/tini", "--", "/usr/bin/env", "bash", "/server_entrypoint.bsh"]

CMD ["sshd"]
