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
until wget -O serf.zip https://dl.bintray.com/mitchellh/serf/0.4.0_linux_amd64.zip; do
    sleep 1
done
unzip serf.zip
sudo mv serf /usr/local/bin/serf

# The member join script is invoked when a member joins the Serf cluster.
# Our join script simply adds the node to the load balancer.
cat <<EOF >/tmp/join.sh
#!/usr/bin/env bash
if [ "\${SERF_SELF_ROLE}" == "mon" ]; then
  MON="true"  
fi
if [ "\${SERF_SELF_ROLE}" != "lb" ]; then
    if [ "\$MON" != "true" ]; then
      echo "Not lb or mon. Ignoring member join." | tee /tmp/join.log
      exit 0
    fi
fi


while read line; do
    NAME=\`echo \$line | awk '{print \\\$1 }'\`
    IP=\`echo \$line | awk '{print \\\$2 }'\`
    ROLE=\`echo \$line | awk '{print \\\$3 }'\`

    env >> /tmp/member-join.log
    echo "\$SERF_SELF_ROLE \$NAME \$IP \$ROLE" >> /tmp/member-join.log

    if [ "\${SERF_SELF_ROLE}" == "lb" ]; then
        if [ "\${ROLE}" == "web" ]; then
            eval "sed -i 's/#HTTPINSERVER/    server \$NAME \$IP:80 check\\n#HTTPINSERVER/g' /etc/haproxy/haproxy.cfg" | tee /tmp/mod.log
        fi
        if [ "\${ROLE}" == "mon" ]; then
            eval "sed -i 's/#MONINSERVER/    server \$NAME \$IP:80 check\\n#MONINSERVER/g' /etc/haproxy/haproxy.cfg" | tee /tmp/mod.log
        fi
        /etc/init.d/haproxy reload
        echo "HAPROXY" >> /tmp/mod.log
    elif [ "\${SERF_SELF_ROLE}" == "mon" ]; then
        if [ ! -d /etc/nagios3/conf.d ]; then
           mkdir -p /etc/nagios3/conf.d
        fi
        cat <<EOL > /etc/nagios3/conf.d/\$NAME.cfg
define host { 
	host_name			\$NAME
	alias				\$NAME serf
	address				\$IP
	check_command			check-host-alive
	check_interval			5
	retry_interval			1
	max_check_attempts		5
	check_period			24x7
	notification_interval		30
	notification_period		24x7
	notification_options		d,u,r
}
EOL
        /etc/init.d/nagios3 reload
    fi
        
done
EOF
sudo mv /tmp/join.sh /usr/local/bin/serf_member_join.sh
chmod +x /usr/local/bin/serf_member_join.sh

# The member leave script is invoked when a member leaves or fails out
# of the serf cluster. Our script removes the node from the load balancer.
cat <<EOF >/tmp/leave.sh
#!/usr/bin/env bash
if [ "\${SERF_SELF_ROLE}" == "mon" ]; then
  MON="true"  
fi
if [ "\${SERF_SELF_ROLE}" != "lb" ]; then
    if [ "\$MON" != "true" ]; then
      echo "Not lb or mon. Ignoring member join."
      exit 0
    fi
fi

while read line; do
    if [ "\${SERF_SELF_ROLE}" == "lb" ]; then
        NAME=\`echo \$line | awk '{print \\\$1 }'\`
        sed -i'' "/\${NAME} /d" /etc/haproxy/haproxy.cfg
        /etc/init.d/haproxy reload
    fi
    if [ "\${SERF_SELF_ROLE}" == "mon" ]; then
        rm /etc/nagios3/conf.d/\$1_serf.cfg
        /etc/init.d/nagios3 reload
    fi
done

EOF
sudo mv /tmp/leave.sh /usr/local/bin/serf_member_left.sh
chmod +x /usr/local/bin/serf_member_left.sh


if [ -z "${SERF_ROLE}" ]; then
  SERF_ROLE="unset"
fi

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

if [ "${SERF_ROLE}" == "lb" ]; then
    exit 0
fi

cat <<EOF >/tmp/join.conf
description "Join the serf cluster"

start on runlevel [2345]
stop on runlevel [!2345]

task
respawn

script
    exec /usr/local/bin/serf join 10.0.0.5
end script
EOF
sudo mv /tmp/join.conf /etc/init/serf-join.conf
sudo start serf-join
