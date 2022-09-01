#!/bin/bash

#set -o xtrace

# parameters
#   (1) : pgpool ip
#   (2) : attach node number

PGPOOL_HOST="$1"
NODE="$2"

if [ -z "$PGPOOL_HOST" ]; then
    echo Pleass enter the pgpool host ..
    exit 1
fi

if [ -z "$NODE" ]; then
    NODE=`cat /etc/pgpool-II/pgpool_node_id`
fi

echo [ $(date +%Y-%m-%d) $(date +%H:%M:%S) ] attach: start: pcp_attach_node .. \
    pgpool_host = ${PGPOOL_HOST}, attach_node = ${NODE}

echo [ $(date +%Y-%m-%d) $(date +%H:%M:%S) ] attach:
sudo -u postgres pcp_attach_node -h ${PGPOOL_HOST} -p 9898 -U postgres -n ${NODE}

