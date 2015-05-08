# haproxy-peers-demo
Vagrant based demo for Sticky Sessions that survive HAProxy reloads and are also synced between two separate HAProxy instances.

# Get started
* Install [Vagrant](https://www.vagrantup.com)
* Clone the repository, e. g. into `~/vagrant/haproxy-peers-demo`
* In the checked out directory execute `vagrant up`

This will start 3 virtual machines:

1. _web_ -- Running Apache with several virtual hosts to simulate multiple backends to balance requests to.
1. _haproxy-1_ -- Running haproxy 1.5, configured to balance requests to the _web_ instance
1. _haproxy-2_ -- The same as haproxy 1.5, configured as a peer to _haproxy-1_

Having two load balancers, but only one web instance might seem strange, but it keeps the number of VMs low.
The higher number of web servers is simulated by virtual hosts in Apache.

Once Vagrant has started the VMs you can access these URLs from a browser of your choice:

  * [haproxy-1 status page](http://localhost:8404/monitor)
  * [haproxy-2 status page](http://localhost:9404/monitor)

## Synchronization across haproxy instances

Access some resources through `haproxy-1` (port 8080). You can use the `access-1.sh` script. It expects two numbers as parameters that will help to generate cookie values.

This is the content of the script:
```
#!/bin/bash
for x in $(seq ${1} ${2}); do
   printf "%05d - " ${x};
   curl -H "Cookie: c1=1; c2=2; JSESSIONID=$(md5 -q -s _${x})" http://localhost:8080;
done
```

Call it like this:
```
$ ./access-1.sh 1 5
```

You will see which backend responded to each request:

```
00001 - Backend 1
00002 - Backend 2
00003 - Backend 3
00004 - Backend 4
00005 - Backend 5
```

Running the same 5 requests again will yield the same result, even though there are still 2 backends left that have not seen any request so far and would be free. The stickiness based on cookies makes sure they reach the same backend.

Now run some (different) requests against the other load balancer (forwarded port 9080) with `access-2.sh`:

```
./access-2.sh 101 105
```

You will see responses similar to before:
```
00101 - Backend 1
00102 - Backend 2
00103 - Backend 3
00104 - Backend 4
00105 - Backend 5
```

At first one might have expected the calls to be handled by backends 6,7,1,2,3 because of the round-robin algorithm. It is important to take into account, though, that the peers do their balancing independet of each other! Because `haproxy-2` did not yet receive any requests, and because there were no sessions 101-105 before, it just starts with the first backend.


Now repeat the same requests, but against `haproxy-1` (port 8080):
```
./access-1.sh 101 105
```

This looks promising:
```
00101 - Backend 1
00102 - Backend 2
00103 - Backend 3
00104 - Backend 4
00105 - Backend 5
```

Even though `haproxy-1` had not seen requests for sessions 101-105, and even though by round-robin logic it they would have gone to backend 6,7,1,2,3 they were handled by the correct backends. This proves the two instances on different VMs did keep their session stick-tables in sync.

Now create some more sessions:
```
./access-1.sh 21 25
```

Because the cookies are not in the stick-table yet, round-robin distribution happens as expected...
```
00021 - Backend 6
00022 - Backend 7
00023 - Backend 1
00024 - Backend 2
00025 - Backend 3
```

...and also syncs right over to the other balancer...
```
./access-2.sh 21 25
```

...yielding the same result:
```
00021 - Backend 6
00022 - Backend 7
00023 - Backend 1
00024 - Backend 2
00025 - Backend 3
```

## Preserved stick-tables across reloads

First stop `haproxy-2`
```
vagrant ssh haproxy-2 -c 'sudo service haproxy stop'
```
Then reload `haproxy-1`
```
vagrant ssh haproxy-1 -c 'sudo service haproxy reload'
```
To check re-run a previous set of requests:
```
./access-1.sh 21 25
```
Even though one instance is down and the other one was reloaded, the stick-table survived, yielding the same results as before.
```
00021 - Backend 6
00022 - Backend 7
00023 - Backend 1
00024 - Backend 2
00025 - Backend 3
```
Because `haproxy.cfg` is identical on both load balancers, they both "know" their own host name as a peer to synchronize stick-tables with. This means even when the second server is down, reloading the remaining one will maintain the stickiness information. On reload, the start-stop-script will first fire up a new process which will then find the currently running one (by finding its own host name in the peers list) and transfer its state. Only once "the baton has been passed on" to the new process will the old one shut down.

That way, you can now stop/start and **reload** instances almost at will, provided that _at least one instance remains running_ at any time. Be advised, that using `service haproxy restart` will actually first stop the old instance and then bring up a new one, so if you did this to the last running instance, session information would actually be lost!

