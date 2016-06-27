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

For more specific usage, use *linecook help*


CONFIGURATION
-------------

See test kitchen's documentation for configuring suites and provisioners.

KITCHEN EXTENSIONS
------------------

kitchen.yml is extended to support the following additional attributes:

**inherit**
  Inherit from a previous linecook build. This saves time if there are several builds based on the same ancestor.

  * name - the name of the build to inherit
  * group - the group / branch of the build to inherit
  * tag - the explicit tag, or 'latest' to discovery the latest tag.

PACKAGER
--------

Right now there are two packagers supported. The interface may change.

**squashfs**
  Package the resulting build as a squashfs image.

  * *excludes* - a list of glob expressions to exclude from the archive

  * *distro* - inherit a specific set of presets for paths to exclude by distro. Currently only ubuntu is supported.

  * outdir - the output directory for the image

**packer**
  Package an AMI using packer. Currently only AMIs are supported, but any packer builder could be implemented relatively easily.

  * hvm - build an HVM instance (defaults to true).

  * root\_size - the size of the root volume to snapshot for the AMI (in GB).

  * region - the region to build the AMI in.

  * copy\_regions - additional regions to copy the AMI to.

  * account\_ids - a list of account ids that are permitted to launch this AMI.

  * ami - details for storing the AMI ID in a DNS TXT record on route53.

    * update\_txt - should a TXT record be written? (true or false)
    * regions - a dictionary of regional aliases
    * domain - the route53 domain to write to
    * zone - the zone within the domain.

SECRETS
-------

Linecook will look for secrets in config.ejson. In particular:

**imagekey**
  the key to use when encrypting images. Generate one with the *image keygen* command.


**aws**
  This is used access to S3, as well as to create EBS based AMIs and update TXT records on route53. A sample IAM policy is provided in the github repo.

  * { "s3": { "bucket" : "name" } } can be used to set the name of the bucket

  * { "access\_key" : "ACCESS\_KEY" } can be used to set the access key for the IAM user associated with the profile with the necessary access.

  * { "secret\_key" : "ACCESS\_KEY" } can be used to set the secret key for the IAM user associated with the profile with the necessary access.

**chef**
  To decrypt data bags securely, you can set the *encrypted\_data\_bag\_secret* here. Make sure any newlines are replaced with \n.


PROVISIONERS
------------

Currently only the docker driver is supported for provisioning. You must have docker installed to use this provisioner.


DEPENDENCIES
-----

**Common**

* Ruby 2.0 or greater, gem, and bundler.

**Linux**

* mksquashfs - to generate squashfs output.

**OS X**

* docker for mac

BUGS
----

Report bugs against github.com/shopify/linecook-gem

AUTHOR
------

Dale Hamel <dale.hamel@shopify.com>
