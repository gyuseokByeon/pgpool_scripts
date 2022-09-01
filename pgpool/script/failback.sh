#!/bin/bash

set -o xtrace

FAILED_NODE_HOST="$1"

PGHOME=/usr/pgsql-13
REPL_SLOT_NAME=${FAILED_NODE_HOST//[-.]/_}
SSH_USER=postgres
PGPOOL_HOST=192.168.0.222
LOG=/data/pgpool/log/recovery_$(date +%Y-%m-%d).log

FAILED_NODE_ID=`ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${FAILED_NODE_HOST} -i /var/lib/pgsql/.ssh/id_rsa_pgpool\
     cat /etc/pgpool-II/pgpool_node_id`

echo failback.sh: start: failed_node_id=$FAILED_NODE_ID failed_host=$FAILED_NODE_HOST

## Down node recovery
echo failback.sh: recovery: node ${FAILED_NODE_ID} on ${PGPOOL_HOST} by postgres user

sudo -u postgres pcp_recovery_node -h ${PGPOOL_HOST} -p 9898 -U postgres -n ${FAILED_NODE_ID} -w >> $LOG

# if [ $? -ne 0 ]; then
#     echo ERROR: failback.sh: end: failback failed
#     exit 1
# fi

echo failback.sh: end $?: new_standby_node_id=${FAILED_NODE_ID} on ${FAILED_NODE_HOST} is promoted to a standby
exit 0
