

# Quirks

+ Overlayfs doesn't support unix domain sockets (yet), so anything using a unix domain socket outside of the /run tree should do manually symlink to /run.
+ Config file will allow you to explicitly mount tmpfs over things that don't do /run if you need to create unix domain sockets
