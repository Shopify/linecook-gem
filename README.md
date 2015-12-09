

# Quirks

+ Overlayfs doesn't support unix domain sockets (yet), so anything using a unix domain socket outside of the /run tree should do manually symlink to /run.
