#!/bin/sh

# Prepare
working_dir=$(mktemp -d)
chown edguser:edguser ${working_dir}

# Configure the BDII
sed "s#/opt/glite/etc/gip#${working_dir}#"  /opt/bdii/etc/bdii.conf > ${working_dir}/bdii.conf
sed -i "s#BDII_READ_TIMEOUT=.*#BDII_READ_TIMEOUT=3#"  ${working_dir}/bdii.conf
sed -i "s#BDII_BREATHE_TIME=.*#BDII_BREATHE_TIME=5#"  ${working_dir}/bdii.conf
sed -i "s#ERROR#DEBUG#"  ${working_dir}/bdii.conf
sed -i "s#/var/log/bdii#${working_dir}#"  ${working_dir}/bdii.conf

# Configure providers
mkdir ${working_dir}/ldif ${working_dir}/provider ${working_dir}/plugin

cat <<EOF > ${working_dir}/ldif/default.ldif
dn: o=grid
objectClass: organization
o: grid

dn: mds-vo-name=local,o=grid
objectClass: MDS
mds-vo-name: local

dn: mds-vo-name=resource,o=grid
objectClass: MDS
mds-vo-name: resource

dn: mds-vo-name=site,o=grid
objectClass: MDS
mds-vo-name: site

EOF

cat <<EOF > ${working_dir}/ldif/service.ldif
dn: GlueServiceUniqueID=service_1,mds-vo-name=resource,o=grid
objectClass: GlueTop
objectClass: GlueService
objectClass: GlueKey
objectClass: GlueSchemaVersion
GlueServiceUniqueID: service_1
GlueServiceName: Test Service One
GlueServiceType: bdii
GlueServiceVersion: 3.0.0
GlueServiceEndpoint: ldap://host-invalid:2170/mds-vo-name=resource,o=grid
GlueServiceStatus: OK
GlueServiceStatusInfo: BDII Runnning
GlueServiceAccessControlBaseRule: dteam
GlueServiceAccessControlBaseRule: atlas
GlueForeignKey: GlueSiteUniqueID=my-site-name
GlueSchemaVersionMajor: 1
GlueSchemaVersionMinor: 3

EOF


echo "site  ldap://$(hostname -f):2170/mds-vo-name=resource,o=grid" > ${working_dir}/site-urls.conf

cat << EOF > ${working_dir}/provider/site-provider
#!/bin/sh
/opt/glite/libexec/glite-info-provider-ldap -c ${working_dir}/site-urls.conf -m site
EOF

echo "grid  ldap://$(hostname -f):2170/mds-vo-name=site,o=grid" > ${working_dir}/grid-urls.conf

cat <<EOF > ${working_dir}/provider/grid-provider
#!/bin/sh
/opt/glite/libexec/glite-info-provider-ldap -c ${working_dir}/grid-urls.conf -m local
EOF

chmod +x ${working_dir}/provider/* 

export BDII_CONF=${working_dir}/bdii.conf
/etc/init.d/bdii restart

RETVAL=0
echo "Waiting 10 second for the BDII to start."
sleep 10

echo -n "Testing resource BDII: "
command="ldapsearch -LLL -x -h $(hostname -f) -p 2170 -b mds-vo-name=resource,o=grid"
filter=GlueServiceUniqueID
${command} ${filter} | grep "service_1" >/dev/null 2>/dev/null 
if [ $? -gt 0 ]; then
    echo "FAIL"
    RETVAL=1
else
    echo "OK"
fi 

echo "Wating for first update ..."
sleep 10


echo -n "Testing site BDII: "
command="ldapsearch -LLL -x -h $(hostname -f) -p 2170 -b mds-vo-name=site,o=grid"
filter=GlueServiceUniqueID
${command} ${filter} | grep "service_1" >/dev/null 2>/dev/null 
if [ $? -gt 0 ]; then
    echo "FAIL"
    RETVAL=1
else
    echo "OK"
fi 

echo "Wating for second update ..."
sleep 10

echo -n "Testing top BDII: "
command="ldapsearch -LLL -x -h $(hostname -f) -p 2170 -b mds-vo-name=local,o=grid"
filter=GlueServiceUniqueID
${command} ${filter} | grep "service_1" >/dev/null 2>/dev/null 
if [ $? -gt 0 ]; then
    echo "FAIL"
    RETVAL=1
else
    echo "OK"
fi 

/etc/init.d/bdii stop
mv ${working_dir}/bdii-update.log /tmp
rm -rf ${working_dir}


if [ ${RETVAL} -eq 1 ]; then
    echo "Test Failed"
    exit 1
else
    echo "Test Passed"
    exit 0
fi
