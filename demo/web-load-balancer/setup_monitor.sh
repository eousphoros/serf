#!/bin/sh
set -e

# Install Nagios

echo postfix postfix/master_upgrade_warning  boolean  | debconf-set-selections
echo postfix postfix/db_upgrade_warning  boolean true | debconf-set-selections
echo postfix postfix/mailname    string  localhost | debconf-set-selections
echo postfix postfix/tlsmgr_upgrade_warning  boolean  | debconf-set-selections
echo postfix postfix/recipient_delim string  + | debconf-set-selections
echo postfix postfix/dynamicmaps_upgrade_warning boolean  | debconf-set-selections
echo postfix postfix/main_mailer_type    select  Satellite system | debconf-set-selections
echo postfix postfix/transport_map_warning   note     | debconf-set-selections
echo postfix postfix/relayhost   string  localhost | debconf-set-selections
echo postfix postfix/procmail    boolean false | debconf-set-selections
echo postfix postfix/bad_recipient_delimiter note     | debconf-set-selections
echo postfix postfix/chattr  boolean false | debconf-set-selections
echo postfix postfix/root_address    string   | debconf-set-selections
echo postfix postfix/rfc1035_violation   boolean false | debconf-set-selections
echo postfix postfix/mydomain_warning    boolean  | debconf-set-selections
echo postfix postfix/mynetworks  string  127.0.0.0/8 | debconf-set-selections
echo postfix postfix/destinations    string  localhost.localdomain, localhost | debconf-set-selections
echo postfix postfix/nqmgr_upgrade_warning   boolean  | debconf-set-selections
echo postfix postfix/not_configured  note     | debconf-set-selections
echo postfix postfix/mailbox_limit   string  0 | debconf-set-selections
echo postfix postfix/protocols   select  all | debconf-set-selections

PASSWORD="DONTCARE1"

echo nagios3-cgi nagios3/adminpassword password $PASSWORD | debconf-set-selections
echo nagios3-cgi nagios3/adminpassword-repeat password $PASSWORD | debconf-set-selections

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -o Dpkg::Options::='--force-confnew' -y -q --force-yes postfix nagios3 | tee /tmp/install.log

# Start it
sudo /etc/init.d/nagios3 start
