#!/bin/sh
set -e

# Install Nagios
echo "DemoMonitor" > /tmp/mailname
sudo mv /tmp/mailname /etc/mailname

echo <<EOF > /tmp/main.cf
# See /usr/share/postfix/main.cf.dist for a commented, more complete version


# Debian specific:  Specifying a file name will cause the first
# line of that file to be used as the name.  The Debian default
# is /etc/mailname.
#myorigin = /etc/mailname

smtpd_banner = $myhostname ESMTP $mail_name (Ubuntu)
biff = no

# appending .domain is the MUA's job.
append_dot_mydomain = no

# Uncomment the next line to generate "delayed mail" warnings
#delay_warning_time = 4h

readme_directory = no

# TLS parameters
smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
smtpd_use_tls=yes
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache

# See /usr/share/doc/postfix/TLS_README.gz in the postfix-doc package for
# information on enabling SSL in the smtp client.

myhostname = ip-10-0-1-148.us-west-2.compute.internal
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = /etc/mailname
mydestination = ip-10-0-1-148.us-west-2.compute.internal, localhost.us-west-2.compute.internal, localhost
relayhost = 
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = loopback-only
default_transport = error
relay_transport = error
EOF
sudo mkdir -p /etc/postfix
sudo mv /tmp/main.cf /etc/postfix/main.cf

PASSWORD="DONTCARE1"

echo nagios3-cgi nagios3/adminpassword password $PASSWORD | debconf-set-selections
echo nagios3-cgi nagios3/adminpassword-repeat password $PASSWORD | debconf-set-selections

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y -q --force-yes postfix nagios3 | tee /tmp/install.log

# Start it
sudo /etc/init.d/nagios3 start
