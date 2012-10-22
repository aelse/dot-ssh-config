dot-ssh-config
==============

Generate SSH client configurations without considering the nitty-gritty.

Why?
----

If you work with hosts in a number of firewalled environments you have
probably felt the pain of getting access to your systems.

Symptoms include:
* Inconsistent (or no) DNS in some environments
* Heavily segregated networks
* Not much, if any, communication between environments
* You have trouble ensuring everyone in your team has access to the same hosts
* Jump hosts, jump hosts, jump hosts

**dot-ssh-config can help you manage your own access to hosts in all of
your environments by taking the pain out of maintaining your ssh config
file.**

Security
--------

Using dot-ssh-config will not create new risks above manually maintaining an
ssh config file yourself.

Any port forwarding has risks of unauthorised individuals getting access
to network resources they shouldn't be able to reach.

Tunnels are set up by listening on the system's loopback address. Only
local users should be able to access these port forwards.
You should be aware of that.

How to use it
-------------

It's easy. Just run this command: `perl dot-ssh-config-sock.pl < myinputfile > ~/.ssh/config`

Then you can establish the tunnels by ssh'ing into your jump hosts.
After that you're able to ssh from a terminal session on your
workstation without having to manually ssh into each jump host before
getting onto the server you need.

For example, if you have a configuration like this:

    jumpbox 192.168.99.99 {
      magicbeans 10.9.9.1
      beanstalk 10.9.9.9 {
        goldengoose 10.8.8.8
      }
    }

you could establish an ssh session to `jumpbox` then leave it open and
forget about it. Thereafter you may pop up a new local terminal session
and use `ssh magicbeans` or `ssh beanstalk` to access those servers. And
of course if you have a session open to beanstalk you can `ssh
goldengoose` from your local terminal without worrying about the
intermediary hops.

All the "magic beans" are inside your input file. Have a look at the below
examples and try running dot-ssh-config against the included example-input
to see what a generated ssh config file looks like.

Example configurations
----------------------

The simplest example

    host1 192.168.0.10

If the host is dns resolvable of course that's ok

    host1a someserver.example.com

Similar, but login as root user

    host2 192.168.0.20 User=root

You can also provide ssh options

    host3 192.168.0.21 ServerAliveInterval=10

The server may have ssh listening on a strange port

    host4 192.168.0.22 Port=2828

A straight-forward local tunneled port example

    webproxy 192.168.0.30 forward=3128:localhost:3128

Or tunnel to another host

    webproxy 192.168.0.31 forward=8080:proxy1.example.com:8080 forward=2222:proxy1.example.com:22

An example jump host, with dns resolvable on the jump host

    jumpbox1 192.168.0.40 {
      webserver1 web1.my-internal-dns.com
      dbserver1 10.0.0.200 User=mysql
    }

And of course we can chain jump hosts

    jumpbox2 192.168.0.50 {
      jumpbox3 10.0.0.50 {
        jumpbox4 10.1.1.10 {
          qwerty 10.2.2.42
        }
      }
    }
