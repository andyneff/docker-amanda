Amanda (The Advanced Maryland Automatic Network Disk Archiver) has been around
for a long time. Having had no tape or *real* backup archiving experience what
so ever, I found it difficult to set up understand how to set up Amanda. 
There are many tutorials out there that try to make this easy, and when you put
them all together they do help a lot. But I was not able to find any "here's a
docker, now run!" So here is my docker solution

While Amanda can be run on a single computer I focused on the setup for me where
I had a single backup "Amanda server" and come "Amanda clients". In Amanda, the 
clients actually run daemons and the server connects to the client. The clients
become the easier part to configure.

#Client

```
docker run -d --restart=always -p 10080:10080 --name amanda_client -v /host_dir:/docker_dir andyneff/amanda:client
```

where /host_dir is whatever directory you want to backup. Fire this docker up
and forget your backup worries. Its DONE!

# Server

The server is different. Instead of running a daemon, every command has to be 
run in a new container. The setting/logs/index are stored outside the container.

Furthermore the server will have far more configuration options you will want to
customize. I have in included a simplified version of [this](http://www.zmanda.com/quick-backup-setup.html)
using a virtual tape disk as the backup between a client and server. To test 
this out on a single computer, use the `just` script included to start the 
containers.

```
./just client
./just server label_vdisk
./just server amcheck daily
```

At this point, you should see:

```
Amanda Backup Client Hosts Check
--------------------------------
Client check: 1 host checked in 2.081 seconds.  0 problems found.
```

To test an actual backup:

```
./just server amdump daily
```

# Common problems

- ERROR: NAK, looks like 

```
Amanda Backup Client Hosts Check
--------------------------------
ERROR: NAK 1.2.3.4: host nwstrtrj01.rd.lv.cox.cci: port 44848 not secure
```

The client only *needs* port [10080](https://wiki.zmanda.com/index.php/How_To:Set_Up_iptables_for_Amanda). 
However SOME times bsdauth uses another (random) port. What do I mean 
sometimes? I don't understand it, but using the exact same docker image on 
some computers works, and on others it does not. If you get this error message, the port number will change randomly
everytime. The only solution I found was to add the hosts network to the client of issue, so
`--network=host`/`--net=host` (depending on the version of docker you are using)
