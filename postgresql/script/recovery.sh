#!/bin/bash

#set -o xtrace

# parameters
#   (1) : to node ip
#   (2) : from node ip
#   recovery to (1) from (2)

PRIMARY_NODE_HOST="$1"
DEST_NODE_HOST="$2"

DEST_NODE_PORT=5432
DEST_NODE_PGDATA=/data/postgresql/data
PRIMARY_NODE_PORT=5432
PGDATA_BACKUP=/data/postgresql/backup

PGHOME=/usr/pgsql-13
ARCHIVEDIR=/data/postgresql/archive
REPLUSER=repl

if [ -z "$PRIMARY_NODE_HOST" ]; then
    echo Pleass enter the primary node host ...
    exit 1
fi

if [ -z "$DEST_NODE_HOST" ]; then
    DEST_NODE_HOST=`ip addr | grep "inet " | grep brd | awk '{print $2}' | awk -F/ '{print $1}'`
fi

REPL_SLOT_NAME=${DEST_NODE_HOST//[-.]/_}

echo [ $(date +%Y-%m-%d) $(date +%H:%M:%S) ] recovery: start: pg_rewind for ${DEST_NODE_HOST}

## Test passwordless SSH
echo [ $(date +%Y-%m-%d) $(date +%H:%M:%S) ] recovery: test passwordless ssh ...
ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null postgres@${DEST_NODE_HOST} -i ~/.ssh/id_rsa_pgpool ls /tmp > /dev/null

if [ $? -ne 0 ]; then
    echo [ $(date +%Y-%m-%d) $(date +%H:%M:%S) ] recovery: passwordless SSH to postgres@${DEST_NODE_HOST} failed. Please setup passwordless SSH. 
    exit 1
fi

## Get PostgreSQL major version
PGVERSION=`${PGHOME}/bin/initdb -V | awk '{print $3}' | sed 's/\..*//' | sed 's/\([0-9]*\)[a-zA-Z].*/\1/'`
if [ $PGVERSION -ge 12 ]; then
    #RECOVERYCONF=${DEST_NODE_PGDATA}/myrecovery.conf
    RECOVERYCONF=${DEST_NODE_PGDATA}/postgresql.auto.conf
else
    RECOVERYCONF=${DEST_NODE_PGDATA}/recovery.conf
fi

## Create replication slot "${REPL_SLOT_NAME}"
sudo -u postgres ${PGHOME}/bin/psql -h ${PRIMARY_NODE_HOST} -p ${PRIMARY_NODE_PORT} \
    -c "SELECT pg_create_physical_replication_slot('${REPL_SLOT_NAME}');"  >/dev/null 2>&1

if [ $? -ne 0 ]; then
    echo [ $(date +%Y-%m-%d) $(date +%H:%M:%S) ] ERROR: recovery: create replication slot \"${REPL_SLOT_NAME}\" failed. You may need to create replication slot manually. 
    echo 1
fi

## Execute pg_rewind to recovery Standby node
echo [ $(date +%Y-%m-%d) $(date +%H:%M:%S) ] recovery: execute pg_rewind ... ${RECOVERYCONF} \
"   
    primary_conninfo = 'host=${PRIMARY_NODE_HOST} port=${PRIMARY_NODE_PORT} user=${REPLUSER} application_name=${DEST_NODE_HOST} passfile=''/var/lib/pgsql/.pgpass'''
    recovery_target_timeline = 'latest'
    restore_command = 'scp ${PRIMARY_NODE_HOST}:${ARCHIVEDIR}/%f %p'
    primary_slot_name = '${REPL_SLOT_NAME}'
"

ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null postgres@$DEST_NODE_HOST -i ~/.ssh/id_rsa_pgpool "

    set -o errexit

    sudo systemctl stop postgresql-13

    tar -cf $PGDATA_BACKUP/data.$(date +%Y%m%d%H%M%S).tar $DEST_NODE_PGDATA/
    ${PGHOME}/bin/pg_rewind -D ${DEST_NODE_PGDATA} --source-server=\"user=postgres host=${PRIMARY_NODE_HOST} port=${PRIMARY_NODE_PORT}\"

    rm -rf ${DEST_NODE_PGDATA}/pg_replslot/*

    cat > ${RECOVERYCONF} << EOT
primary_conninfo = 'host=${PRIMARY_NODE_HOST} port=${PRIMARY_NODE_PORT} user=${REPLUSER} application_name=${DEST_NODE_HOST} passfile=''/var/lib/pgsql/.pgpass'''
recovery_target_timeline = 'latest'
restore_command = 'scp ${PRIMARY_NODE_HOST}:${ARCHIVEDIR}/%f %p'
primary_slot_name = '${REPL_SLOT_NAME}'
EOT

    if [ ${PGVERSION} -ge 12 ]; then
        sed -i -e \"\\\$ainclude_if_exists = '$(echo ${RECOVERYCONF} | sed -e 's/\//\\\//g')'\" \
                -e \"/^include_if_exists = '$(echo ${RECOVERYCONF} | sed -e 's/\//\\\//g')'/d\" ${DEST_NODE_PGDATA}/postgresql.conf
        touch ${DEST_NODE_PGDATA}/standby.signal
    else
        echo \"standby_mode = 'on'\" >> ${RECOVERYCONF}
    fi

    sudo systemctl start postgresql-13

"

if [ $? -ne 0 ]; then

    sudo -u postgres ${PGHOME}/bin/psql -h ${PRIMARY_NODE_HOST} -p ${PRIMARY_NODE_PORT} \
        -c "SELECT pg_drop_replication_slot('${REPL_SLOT_NAME}');"  >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo [ $(date +%Y-%m-%d) $(date +%H:%M:%S) ] ERROR: recovery: drop replication slot \"${REPL_SLOT_NAME}\" failed. You may need to drop replication slot manually. 
    fi

    echo [ $(date +%Y-%m-%d) $(date +%H:%M:%S) ] ERROR: recovery: end: pg_rewind failed. online recovery failed 
    exit 1
fi

echo [ $(date +%Y-%m-%d) $(date +%H:%M:%S) ] recovery: end: recovery is completed successfully 
exit 0

