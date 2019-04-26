#!/bin/bash

# https://docs.aws.amazon.com/opsworks/latest/userguide/workinginstances-custom-ami.html

systemctl stop opsworks-agent
rm -rf /etc/aws/opsworks/ /opt/aws/opsworks/ /var/log/aws/opsworks/ /var/lib/aws/opsworks/ /etc/monit.d/opsworks-agent.monitrc /etc/monit/conf.d/opsworks-agent.monitrc /var/lib/cloud/ /var/chef /opt/chef /etc/chef
apt-get -y remove chef
dpkg -r opsworks-agent-ruby
