privateIp=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
privateDnsName=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
sudo sleep 3
sudo hostname ${privateDnsName}
sudo echo -e "${privateDnsName}" >> /etc/hostname
sudo echo -e "HOSTNAME=${privateDnsName}" >> /etc/sysconfig/network
sudo echo -e "preserve_hostname: true" >> /etc/cloud/cloud.cfg
sudo service network restart
