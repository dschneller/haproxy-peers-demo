# haproxy-peers-demo
Vagrant based demo for Sticky Sessions that survive HAProxy reloads and are also synced between two separate HAProxy instances.

# Get started
* Install [Vagrant](https://www.vagrantup.com)
* Clone the repository, e. g. into `~/vagrant/haproxy-peers-demo`
* In the checked out directory execute `vagrant up`

This will start 3 virtual machines:

1. web -- Running Apache with several virtual hosts to simulate multiple backends to balance requests to.
1. haproxy-1 -- Running haproxy 1.5, configured to balance requests to the _web_ instance
1. haproxy-2 -- The same as haproxy 1.5, configured as a peer to _haproxy-1_

Having two load balancers, but only one web instance might seem strange, but it keeps the number of VMs low.
The higher number of web servers is simulated by virtual hosts in Apache.

Once Vagrant has started the VMs you can access these URLs from a browser of your choice:

  * [haproxy-1 status page](http://localhost:8404/monitor)
  * [haproxy-2 status page](http://localhost:9404/monitor)


## Synchronization across haproxy instances

Access some resources through _haproxy-1_ (port 8081)
```
$ for x in $(seq 1 5); do
>   printf "%05d - " ${x};
>   curl -H "Cookie: c1=1; c2=2; JSESSIONID=$(md5 -q -s _${x})" http://localhost:8081;
> done
```
You will see which backend responded to each request:

```
00001 - Backend 4
00002 - Backend 7
00003 - Backend 1
00004 - Backend 5
00005 - Backend 6
```

Running the same 5 requests again will yield the same result, even though there are still 2 backens left that
have not seen any request so far.

Now run some requests against the other load balancer (forwarded port 9081):

```
$ for x in $(seq 101 105); do
>   printf "%05d - " ${x};
>   curl -H "Cookie: c1=1; c2=2; JSESSIONID=$(md5 -q -s _${x})" http://localhost:9081;
> done
```

You will see another set of backends responding:
```
00101 - Backend 7
00102 - Backend 3
00103 - Backend 1
00104 - Backend 5
00105 - Backend 6
```

Now repeat the same requests, but against _haproxy-1_ (port 8081):
```
00101 - Backend 7
00102 - Backend 3
00103 - Backend 1
00104 - Backend 5
00105 - Backend 6
```
As you can see, the two instances, even on different VMs have synchronized their session stick-tables.

## Preserved stick-tables across reloads

* Stop _haproxy-2_

        vagrant ssh haproxy-2 -c 'sudo service haproxy stop'

* Reload _haproxy-1_

        vagrant ssh haproxy-1 -c 'sudo service haproxy reload'

* Re-Run a previous set of requests:

        $ for x in $(seq 1 5); do
        >   printf "%05d - " ${x};
        >   curl -H "Cookie: c1=1; c2=2; JSESSIONID=$(md5 -q -s _${x})" http://localhost:8081;
        > done

  Even though one instance is down and the other one was reloaded, the stick-table
  survived, yielding the same results as before.

        00001 - Backend 4
        00002 - Backend 7
        00003 - Backend 1
        00004 - Backend 5
        00005 - Backend 6
