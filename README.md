Amanda (The Advanced Maryland Automatic Network Disk Archiver) has been around
for a long time. Having had no tape or *real* backup archiving experience what
so ever, I found it difficult to set up understand how to set up Amanda.
There are many tutorials out there that try to make this easy, and when you put
them all together they do help a lot. But I was not able to find any "here's a
docker, now run!" So here is my docker solution

While Amanda can be run on a single computer I focused on the setup for me where
I had a single backup "Amanda server" and some "Amanda clients". In Amanda, the
clients actually run daemons and the server connects to the client. The clients
become the easier part to configure.

vsidata is my specific configuration I use and docker compose files are specific
to my mount locations, provided as a implementation example. This could be made
more generic with "just"

# Setup

## SSH keys

- SSH keys are auto generated when a container starts. (not at build time, so they
are not in the images). You must transfer the keys between server and client.

```
# On Tape Server
just pull-server-ssh

# On Client
just push-client-ssh

# On Client
just pull-client-ssh
# On Tape Server
just push-server-ssh
```

This copies the public key locally. Either copy them between the server or client,
or use `DOCKER_HOST` to access remote docker servers from a single system.

## GPG Keys

You need a secure password (but one that WILL be stored plain text...) store

```
# Optional
just gpg-suggest-password
# Store password somewhere offline and safe

just gpg-keys
```

# J.U.S.T.

To use the just script, source the environment script and you are good to go

```
source ./setup.env

# Optional
just --help
```

# Client

```
# On Client
just client
```

Fire this docker up and forget your backup worries (it auto restart).

# Server

The server is different. Instead of running a daemon, every command has to be
run in a new container. The setting/logs/index are stored in an internal docker
volume.

Furthermore the server will have far more configuration options you will want to
customize. I have in included a simplified version of [this](http://www.zmanda.com/quick-backup-setup.html)
using a virtual tape disk as the backup between a client and server. To test
this out on a single computer, use the `just` script included to start the
containers.

You can get your configuration into the volume however you like. One such
example is

To check your configuration, run

```
# On Tape Server
just check
```

At this point, you should see:

```
Amanda Backup Client Hosts Check
--------------------------------
Client check: 1 host checked in 2.081 seconds.  0 problems found.
```

To test an actual backup:

```
# On Tape Server
just backup
```

# Restoring

To start a restore, start the server on the backup server

```
# On Tape Server
just server
```

You will need to add the private keys to decrypt the data. These instructions
are specific to the yubikey/GPG cards

1. Plug in your GPG card (YubiKey)
2. Recv public key

```
gpg2 --card-status # Should import the private stubs
gpg2 --card-edit
verify
# Enter pin number This should remember for up to a month. See gpg-agent.conf if this isn't enough
```

3. Now as long as the yubikey is plugged in, the private keys will be accessible
(although locked by pin)