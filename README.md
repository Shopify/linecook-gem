LINECOOK 1 "December 2015" Unix "User Manuals"
=======================================

NAME
----

linecook - system image builder

SYNOPSIS
--------

linecook help [`COMMAND`]- for specific command help

DESCRIPTION
-----------

Linecook builds system images utilizing overlayfs, squashfs, and linux containers via LXC. Currently, linecook only natively supports chef for provisioning, but using packer with a null resource, any of the mechanisms supported by packer are also supported by linecook.

CONFIGURATION
-------------

Describe config file here once it's been determined

FILES
-----

*./linecook.yml*
  Local config file. Gets deep merged over the system config file. If not explicitly specified, found from current directory if exists.

*~/linecook/config.yml*
  The system wide configuration file, base or 'common' configuration. Other configurations get deep merged on top of this.

DEPENDENCIES
-----

Ruby 2.0 or greater, gem, and bundler.

Does not work and will never work on Windows.

### Linux

Only tested on Gentoo and Ubuntu

* lxc >= 1.0.7
* brutils
* dnsmasq
* iptables with masquerade support
* Linux 3.19 or greater with support for cgroups, and netfilter as described by lxc and iptables for NAT.


### OS X

* OS X 10.10 or later (Hypervisor.framework required for Xhyve)

QUIRKS
-----------

### Xhyve

+ Xhyve requires root privileges until https://github.com/mist64/xhyve/issues/60 is resolved. Linecook will setuid on the xhyve binary.

### Overlayfs

+ Overlayfs doesn't support unix domain sockets (yet), so anything using a unix domain socket outside of the /run tree should do manually symlink to /run.
+ Config file will allow you to explicitly mount tmpfs over things that don't do /run if you need to create unix domain sockets

BUGS
----

Report bugs against github.com/dalehamel/linecook

AUTHOR
------

Dale Hamel <dale.hamel@srvthe.net>
