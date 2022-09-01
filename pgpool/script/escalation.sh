#!/bin/bash
# This script is run by wd_escalation_command to bring down the virtual IP on other pgpool nodes
# before bringing up the virtual IP on the new active pgpool node.

set -o xtrace

#PGPOOLS=(server1 server2 server3)
PGPOOLS=(192.168.0.218 192.168.0.219)
VIP=192.168.0.222
DEVICE=eth0
SSL_USER=postgres

for pgpool in "${PGPOOLS[@]}"; do
    [ "$HOSTNAME" = "$pgpool" ] && continue

    ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSL_USER}@$pgpool -i ~/.ssh/id_rsa_pgpool "
        /usr/bin/sudo /sbin/ip addr del $VIP/24 dev $DEVICE
    "
done
exit 0
