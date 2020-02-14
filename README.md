Amanda (The Advanced Maryland Automatic Network Disk Archiver) has been around for a long time. Having had no tape or *real* backup archiving experience what so ever, I found it difficult to set up understand how to set up Amanda, which itself it different from the traditional full/incremental backup style. There are many tutorials out there that try to make this easy, however most of them revolve on backup up to disks, and when you put them all together they do help a lot. But I was not able to find any "here's a docker, now run!" So here is my docker solution, now run!

While Amanda can be run on a single computer I focused on the setup for me where I had a single backup "Amanda server" and some "Amanda clients". In Amanda, the clients actually run daemons and the server connects to the client. The clients become the easier part to configure.

vsidata is my specific configuration I use and docker compose files are specific
to my mount locations, provided as a implementation example. This could be made
more generic with "just"

# J.U.S.T.

To use the just script, source the environment script and you are good to go

```
source ./setup.env

# Optional
just --help
```

# Deployment Environment

Since we are dealing with multiple computers, and moving files between them, I find it easier to remotely connect to multiple computers using `de_activate` found [here](https://gist.github.com/andyneff/26830a64793ea18f6363e5578dc5664f)

In server window:

```bash
de_activate username@server
```

In client window:

```bash
de_activate username@client
```

For some reason, this never worked on Synology NASes. Instead, a reverse activate was used, when you ssh into the Synology and have it ssh back into your local machine. (If you cannot ssh into your local machine, this will not be possible.)

```bash
de_reverse_activate myusername@myhostname username@client # Doesn't work anymore on newer DSM
```

However using the following will `sudo` (on Synology) to `root` and work.

If the client is a computer (like Synology) where *only* `root` has docker access, and `root` has no password, you have to log in first, and then use `sudo` to reverse port forward back to your local machine. This elevation can be done using the `CHANGE_USER` variable:


```bash
CHANGE_USER="sudo" de_activate myusername@myhostname username@client
```

In even more complicated situations, the elevation command can only take one argument (like `su -c`). In these cases, use the `CHANGE_SINGLE` variable instead. The advanced quoting will be taken care of for you.

```bash
CHANGE_SINGLE="sudo su - root -c" de_activate myusername@myhostname username@client
```

These commands don't handle extra gateways in between, etc... But it would be possible to modify them to whatever your configuration is

# Setup

```
git clone https://github.com/VisionSystemsInc/amanda.git
cd amanda
. setup.env
just help
```

You will need to create a `local.env` file to customize to your environment

```
AMANDA_BACKUP_SERVER={SERVER IP ADDRESS}
AMANDA_BACKUP_CLIENTS={CLIENT IP ADDRESS}
AMANDA_CLIENT_SSH_IP="${AMANDA_BACKUP_CLIENTS}"
AMANDA_SERVER_SSH_IP="${AMANDA_BACKUP_SERVER}"

AMANDA_FROM_EMAIL={FROM EMAIL ADDRESS}
AMANDA_SMTP_SERVER={SMTP SERVER}
AMANDA_TO_EMAIL={TO EMAIL ADDRESS}

AMANDA_CONFIG_NAME=vsidata
```

Any other value in `amanda.env` can be overwritten here, but those are the basics.

# Client

Build client images

```
# On Client
just build client
```

Fire this docker up and forget your backup worries (it auto restart).

```bash
just client
```

<kbd>Ctrl</kbd> + <kbd>c</kbd> to stop watching the logs

## Server

Build the server images

```bash
just build server
```

Start the server daemon (needed for when you use `amrestore`)

```bash
just server
```

### Real time index backup

In case the backup server is "lost" due to a disaster, it would be good to have the index to use to restore from the tapes that were stored offsite. To accomplish this, a dropbox container is used to always keep a copy of the index backed up in dropbox. Under normal circumstances, the syncing is one way only (from server to dropbox) so there is no chance of the index being overwritten by dropbox.

1. `docker-compose -f dropbox.yml run dropbox bash`
1. Follow the instructions to link your account
1. Run `/dropbox/.dropbox-dist/dropboxd`
1. Link account
1. Ctrl+Z to background dropbox daemon
1. `bg`
1. cd /dropbox/Dropbox
1. `/dropbox/dropbox.py exclude add *`
1. `/dropbox/dropbox.py exclude remove amanda_etc`
1. `/dropbox/dropbox.py status`
    1. Repeat until you get the "Up to date"
1. If this is the first time setting this up, and you are not restoring from the dropbox backup
    1. `ln -sf "/dropbox/Dropbox (VSI)/amanda_etc" /dropbox/Dropbox/amanda_etc`
1. `exit`

Dropbox will no longer sync read only files. It will mark them as "unsyncable". Create a one way sync with `lsyncd`

#### Restoring from Dropbox backup

If you are trying to restore from the dropbox backup

1. `docker-compose -f dropbox.yml run -v amanda_amanda-config:/data --entrypoint= dropbox bash`
2. `mv /dropbox/Dropbox/amanda_etc/* "/data/``"`
3. This files should now be in `ls "/dropbox/Dropbox (VSI)/amanda_etc/``"`
4. `rmdir /dropbox/Dropbox/amanda_etc`
5. `ln -s "/dropbox/Dropbox (VSI)/amanda_etc" /dropbox/Dropbox/amanda_etc`
6. `exit`

#### Starting Dropbox Sync

Now that dropbox is all setup:

```bash
just dropbox
```

Now the container should stay up, and will even restart on reboot. To check the status at any time:

```bash
docker exec -it amanda_dropbox_1 gosu dropbox /dropbox/dropbox.py status
```

## Copying SSH public keys

- SSH keys are auto generated when a container starts for the first time (not at build time, so they are not in the images). You must transfer the public keys between server and client, and add them to `/etc/keys/authorized_keys`. This can be done manually, or...

Using the "Deployment Environment", this can easily be done by:

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
# Store password somewhere offline and safe, like KeePass

# Generate new GPG keys
just gpg-keys
```

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

To run an actual backup:

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

1. On the client, `cd` to the base directory where you want to restore files
1. `just recover`
    1. Tell amanda which host you are recovering from. `listhost` to see all
    1. `sethost {client host}`
    1. Select the DLE to recover from. `listdisk` to see all
    1. `setdisk {DLE}`
    1. `ls` and `cd` to view the virtual filesystem
    1. (optional) Select time to recover from. `history` to see all.
    1. (optional) `setdata {date}`
    1. Add files/dirs to recover: `add {filenames}`
    1. When you are ready to restore files: `extract`
    1. Insert the tapes as needed.
    1. `exit`

# Troubleshooting

1. `just dropbox status` shows

       Syncing 28 files
       Downloading 28 files...
       Can't sync "amdump" (your file system is read-only)

  - While this shouldn't happen, it can apparently. The files need to be deleted from dropbox (via the website) and refreshed on the server
    1. Move the files to a temp dir
    2. Restart dropbox daemon
    3. Move the files back
