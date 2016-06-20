LINECOOK 1 "June 2016" Unix "User Manuals"
=======================================

NAME
----

linecook - Linux system image builder based on test kitchen

SYNOPSIS
--------

linecook help [`COMMAND`]- for specific command help

DESCRIPTION
-----------

Linecook is a workflow tool that allows you to use test kitchen to build generic system images. Linecook works with arbitrary test-kitchen provisioners, and generations a neutral format that can be packaged into specific output formats.

Currently, linecook supports the following test kitchen drivers:

* kitchen-docker

And linecook uses packer to generate output. It currently supports:

* AMIs via packer's ebs\_chroot builder.
 * The amis may also update a TXT record in a route53 zone once the build is complete
* squashfs, a provider neutral format.

Linecook builds may be saved and annotated according to the folliwng convention:

* name - a descriptive name for the build, based on the name of the test kitchen suite.
* group - an arbitrary grouping of suites, intended to group builds by branches.
* tag - a numeric tag for a build, intended to increment. If 'latest' is specified when resolving a build, the latest uploaded build is used.

These three attributes are composed to make a build id in a very simple manor:

* name is always required
* if group is specified, it will be joined with name using a '-' character.
* if tag is specified, it will be joined with the name and the gorup using a '-' character.
* For example, the resulting id for a base build on the master group, with id of '5' would be 'base-master-5'. If this is the latest build for the base-master group, 'base-master-latest' will resolve to this.

If linecook uploads a build, it will always encrypt it using rbnacl.

USAGE
--------

To test linecook builds locally, it is best to use test kitchen directly:

```
bundle exec kitchen converge [SUITE NAME]
```

Linecook uses 


CONFIGURATION
-------------

See test kitchen's documentation for configuring suites and provisioners.

Linecook supports configuration of packagers, but this is not yet documented as it may change. For now, just read the source code.

Linecook will look for secrets in config.ejson

PROVISIONERS
------------

Currently only the docker driver is supported for provisioning. You must have docker installed to use this provisioner.


DEPENDENCIES
-----

Ruby 2.0 or greater, gem, and bundler.


### Linux


### OS X


QUIRKS
-----------


BUGS
----

Report bugs against github.com/shopify/linecook-gem

AUTHOR
------

Dale Hamel <dale.hamel@shopify.com>
