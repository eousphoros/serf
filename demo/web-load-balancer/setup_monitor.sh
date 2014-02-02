#!/bin/sh
#
# This script sets up the HAProxy load balancer initially, configured with
# no working backend servers. Presumably in a real environment you would
# do this sort of setup with a real configuration management system. For
# this demo, however, this shell script will suffice.
#
set -e

# Install HAProxy
sudo apt-get update
sudo apt-get install -y nagios3

# Start it
sudo /etc/init.d/nagios3 start
