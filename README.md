LINECOOK 1 "December 2015" Unix "User Manuals"
=======================================

NAME
----

linecook - Linux system image builder

SYNOPSIS
--------

linecook setup - interactive setup

linecook help [`COMMAND`]- for specific command help

DESCRIPTION
-----------

Linecook builds system images utilizing overlayfs, squashfs, and linux containers via LXC. Currently, linecook only natively supports chef for provisioning, but using packer with a null resource, any of the mechanisms supported by packer are also supported by linecook.

Linecook is intended to serve 3 main purposes:

* Providing a simple, portable image building process that is useable both in baremetal and cloud deployments.
* Enabling a means of simple local image development with high production efficacy on Linux and OS X.
* Simplifying continuous integration and testing of linux systems.

USAGE
--------

linecook bake SPEC [-n --name `NAME`] [-s --snapshot]
  --name - The name
  --snapshot - Snapshot the resulting image for later use
  --encrypt - Encrypt the snapshot using the configured key. Implies snapshot.
  --upload - Upload the resulting image to the configured destination. Implies snapshot.
  --all - Snapshot, encrypt, and upload the resulting image.
  Build a linecook image defined by SPEC, with an optional name to help identify it. The default will be the SPEC name

linecook builder
  start - start a new builder
  stop - stop a running builder
  info - show the info about the builder
  ip - show the builder's ip

linecook build
  list
  info NAME
  ip NAME
  stop NAME

linecook image
  list
  fetch
  find [`REGEX`] - list available remote images filtered by an optional regex

linecook ami [`image`] [-r --region `REGION1,REGION2`] [-x --xen-type `PV|HVM`] [-r --root-size GIGABYTES] - create an AMI (Amazon Machine Image) from a snapshot.


linecook keygen - generate a new secret key for image encryption

CONFIGURATION
-------------

Describe config file here once it's been determined

PROVISIONERS
------------

Linecook includes an embedded chef-zero server, and uses the [chef-provisioner](https://rubygems.org/gems/chef-provisioner) and [chefdepartie](https://rubygems.org/gems/chefdepartie) gems to have first-class support for local chef-zero builds.

However, if you're not using chef or don't want to use chef-zero, linecook can be used seamlessly with [packer](https://www.packer.io), and supports any of the Linux-based provisioners. This includes:

* Chef-solo
* Chef-client (with a real chef server)
* Ansible
* Puppet (masterless or server)
* Salt
* Plain old shell scripts

See the packer documentation for how to configure these provisioners.

To use a packerfile with linecook, just leave out the 'builder' section, or have the builder section be an empty array. Linecook will automatically insert a null builder with the appropriate connection string for you.

Linecook with packer is a powerful combination, as it allows you to leverage packer's 'null builder' to take advantage of all of the provisioners packer already has really good support for.

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
