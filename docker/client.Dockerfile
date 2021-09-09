FROM vsiri/recipe:tini AS tini

FROM debian:8
LABEL maintainer="Andrew Neff <andrew.neff@visionsystemsinc.com>"

SHELL ["bash", "-euxvc"]

# Install amanda and amanda compatible mailer
RUN apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates openssh-server \
        libxml-simple-perl libjson-perl liburi-escape-xs-perl \
        libdata-dumper-simple-perl libencode-locale-perl curl; \
    curl -fsSLO https://cdn.zmanda.com/downloads/community/Amanda/3.5.1/Debian-8.1/amanda-backup-client_3.5.1-1Debian81_amd64.deb; \
    # Verify the download is a valid deb file
    dpkg -I /amanda-backup-client*.deb ; \
    dpkg -i /amanda-backup-client*.deb || :; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -f; \
    DEBIAN_FRONTEND=noninteractive apt-get purge -y curl --auto-remove; \
    rm /amanda-backup*.deb; \
    rm /etc/ssh/ssh_host*

# Install recipes
COPY --from=tini /usr/local/bin/tini /usr/local/bin/tini

RUN echo "runtar:gnutar_path=/bin/tar" > /etc/amanda-security.conf; \
    chown root:disk /etc/amanda-security.conf; \
    chmod 640 /etc/amanda-security.conf

# Setup Amanda
ADD docker/client_entrypoint.bsh /
ADD vsidata/amanda-client.conf /etc/amanda/
ENV SERVER_NAME=amanda-server \
    BACKUP_USERNAME=amandabackup \
    BACKUP_GROUP=disk
RUN chown ${BACKUP_USERNAME}:${BACKUP_GROUP} /var/lib/amanda/* /var/lib/amanda/.ssh; \
    chown ${BACKUP_USERNAME}:${BACKUP_GROUP} /var/lib/amanda/.gnupg/secring.gpg; \
    chmod 755 /client_entrypoint.bsh; \
    chown ${BACKUP_USERNAME}:${BACKUP_GROUP} /etc/amanda/amanda-client.conf; \
    chmod 640 /etc/amanda/amanda-client.conf; \
    ln -sf /var/lib/amanda/gnutar-lists/amandates /var/amanda/amandates

# Customize sshd
RUN sed -i 's|HostKey /etc/ssh|HostKey /etc/keys|' /etc/ssh/sshd_config; \
    echo AuthorizedKeysFile /etc/keys/authorized_keys >> /etc/ssh/sshd_config; \
    echo PasswordAuthentication no >> /etc/ssh/sshd_config; \
    echo StrictHostKeyChecking no >> /etc/ssh/ssh_config; \
    mkdir /root/.ssh; \
    chmod 700 /root/.ssh; \
    echo "Host *" > /root/.ssh/config; \
    echo "  IdentityFile /etc/keys/id_rsa" >> /root/.ssh/config; \
    mkdir /var/run/sshd; \
    rm /etc/motd

ENV BACKUP_UID=63998 \
    TZ="US/Eastern"

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/tini", "--", "/usr/bin/env", "bash", "/client_entrypoint.bsh"]

CMD ["/usr/sbin/sshd", "-D", "-e"]
