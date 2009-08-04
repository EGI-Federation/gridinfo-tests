#!/bin/sh

# Prepare
HOST=`hostname`
SEC=20

# Run
echo "INFO: Running BDII Resource tests..."
/etc/init.d/bdii restart
echo "Waiting for it to start ($SEC seconds)..."
sleep $SEC
ldapsearch -LLL -x -h $HOST -p 2170 -b mds-vo-name=resource,o=grid '(|(objectClass=GlueCluster)(objectClass=GlueService))' dn
if [ $? -ne 0 ]; then
  echo "No resource information found."
  echo "Test Failed!"
  exit 1
else
  echo "Test Passed"
  exit 0
fi
