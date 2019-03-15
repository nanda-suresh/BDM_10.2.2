echo " " >> /root/.ssh/authorized_keys
cat /opt/infa-imp/infa_keys >> /root/.ssh/authorized_keys
cp /opt/infa-imp/infa_id /root/.ssh/id_rsa.pub
chmod 600 /root/.ssh/authorized_keys /root/.ssh/id_rsa.pub