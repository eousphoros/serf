#!/bin/sh
#
# This script installs and configures the Serf agent that runs on
# every node. As with the other scripts, this should probably be done with
# formal configuration management, but a shell script is simple as well.
#
# The SERF_ROLE environmental variable must be passed into this script
# in order to set the role of the machine. This should be either "lb" or
# "web".
#
set -e

sudo apt-get install -y unzip

# Download and install Serf
cd /tmp
until wget -O serf.zip https://dl.bintray.com/mitchellh/serf/0.3.0_linux_amd64.zip; do
    sleep 1
done
unzip serf.zip
sudo mv serf /usr/local/bin/serf

# The member join script is invoked when a member joins the Serf cluster.
# Our join script simply adds the node to the load balancer.
cat <<EOF >/tmp/join.sh
if [ "x\${SERF_SELF_ROLE}" != "xlb" ]; then
  if [ "x\${SERF_SELF_ROLE}" != "xmon" ]; then
    echo "Not an lb or mon. Ignoring member join."
    exit 0
fi

while read line; do
    NAME=\`echo \$line | awk '{print \\\$1 }'\`
    IP=\`echo \$line | awk '{print \\\$2 }'\`
    ROLE=\`echo \$line | awk '{print \\\$3 }'\`
    if [ "x\${ROLE}" != "xweb" ]; then
        continue
    fi

    if [ "x\${SERF_SELF_ROLE}" == "xlb" ]; then
        if [ "ROLE" == "xweb" ]; then
            sed -i 's/#HTTPINSERVER/    server %s %s check\\n#HTTPINSERVER"/g /etc/haproxy/haproxy.cfg
        elif [ "ROLE" == "xmon" ]; then
            sed -i 's/#MONINSERVER/    server %s %s check\\n#MONINSERVER"/g /etc/haproxy/haproxy.cfg
        fi
        /etc/init.d/haproxy reload
    elif [ "x\${SERF_SELF_ROLE}" == "xmon" ]; then
        cat /etc/nagios3/conf.d/localhost_nagios2.cfg | sed 's/localhost/\$NAME/g' | sed 's/127.0.0.1/\$IP/g' > /etc/nagios3/conf.d/\$NAME_serf.cfg
        /etc/init.d/nagios3 reload
    fi
        
done
EOF
sudo mv /tmp/join.sh /usr/local/bin/serf_member_join.sh
chmod +x /usr/local/bin/serf_member_join.sh

# The member leave script is invoked when a member leaves or fails out
# of the serf cluster. Our script removes the node from the load balancer.
cat <<EOF >/tmp/leave.sh
if [ "x\${SERF_SELF_ROLE}" != "xlb" ]; then
  if [ "x\${SERF_SELF_ROLE}" != "xmon" ]; then
    echo "Not an lb or mon. Ignoring member join."
    exit 0
fi

while read line; do
    if [ "x\${SERF_SELF_ROLE}" == "xlb" ]; then
        NAME=\`echo \$line | awk '{print \\\$1 }'\`
        sed -i'' "/\${NAME} /d" /etc/haproxy/haproxy.cfg
        /etc/init.d/haproxy reload
    elif [ "x\${SERF_SELF_ROLE}" == "xmon" ]; then
        rm /etc/nagios3/conf.d/\$1_serf.cfg
        /etc/init.d/nagios3 reload
    fi
done

EOF
sudo mv /tmp/leave.sh /usr/local/bin/serf_member_left.sh
chmod +x /usr/local/bin/serf_member_left.sh

# Configure the agent
cat <<EOF >/tmp/agent.conf
description "Serf agent"

start on runlevel [2345]
stop on runlevel [!2345]

exec /usr/local/bin/serf agent \\
    -event-handler "member-join=/usr/local/bin/serf_member_join.sh" \\
    -event-handler "member-leave,member-failed=/usr/local/bin/serf_member_left.sh" \\
    -role=${SERF_ROLE} >>/var/log/serf.log 2>&1
EOF
sudo mv /tmp/agent.conf /etc/init/serf.conf

# Start the agent!
sudo start serf

# If we're the web node, then we need to configure the join retry
if [ "x${SERF_ROLE}" != "xweb" ]; then
    exit 0
fi

cat <<EOF >/tmp/join.conf
description "Join the serf cluster"

start on runlevel [2345]
stop on runlevel [!2345]

task
respawn

script
    sleep 5
    exec /usr/local/bin/serf join 10.0.0.5
end script
EOF
sudo mv /tmp/join.conf /etc/init/serf-join.conf
sudo start serf-join
