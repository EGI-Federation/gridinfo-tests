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

dn: mds-vo-name=cert-tb-cern,o=grid
objectClass: MDS
mds-vo-name: cert-tb-cern

EOF


cat <<EOF > ${working_dir}/site-urls.conf
BDII  ldap://lxbra2306.cern.ch:2170/mds-vo-name=resource,o=grid
CE  ldap://lxbra2307.cern.ch:2170/mds-vo-name=resource,o=grid
CREAMCE  ldap://lxbra2308.cern.ch:2170/mds-vo-name=resource,o=grid
CREAMCE2  ldap://vtb-generic-104.cern.ch:2170/mds-vo-name=resource,o=grid
SE  ldap://lxbra1910.cern.ch:2170/mds-vo-name=resource,o=grid
DPM  ldap://lxb7608v1.cern.ch:2170/mds-vo-name=resource,o=grid
LFC  ldap://lxb7608v3.cern.ch:2170/mds-vo-name=resource,o=grid
PX  ldap://lxbra2304.cern.ch:2170/mds-vo-name=resource,o=grid
FTS  ldap://lxbra2310.cern.ch:2170/mds-vo-name=resource,o=grid
CE2  ldap://vtb-generic-100.cern.ch:2170/mds-vo-name=resource,o=grid
FTS  ldap://lxbra2310.cern.ch:2170/mds-vo-name=resource,o=grid
VOBOX  ldap://lxb7607v2.cern.ch.cern.ch:2170/mds-vo-name=resource,o=grid
CEAZ  ldap://lxb8076.cern.ch:2170/mds-vo-name=resource,o=grid
LFCAZER  ldap://vtb-generic-92.cern.ch:2170/mds-vo-name=resource,o=grid
EOF

cat << EOF > ${working_dir}/provider/site-provider
#!/bin/sh
/opt/glite/libexec/glite-info-provider-ldap -c ${working_dir}/site-urls.conf -m cert-tb-cern
EOF

chmod +x ${working_dir}/provider/* 

export BDII_CONF=${working_dir}/bdii.conf
/etc/init.d/bdii restart

RETVAL=0
echo "Waiting 30 second for the BDII to start."
sleep 30

echo -n "Testing site BDII: "
ldapsearch -LLL -x -h $(hostname -f) -p 2170 -b mds-vo-name=cert-tb-cern,o=grid dn | perl -pe 'BEGIN { $/ = "" } s/\n //g' > ${working_dir}/output1
ldapsearch -LLL -x -h lxbra2306 -p 2170 -b mds-vo-name=cert-tb-cern,o=grid dn | perl -pe 'BEGIN { $/ = "" } s/\n //g' > ${working_dir}/output2

cat ${working_dir}/output1 | sort -u > ${working_dir}/output1-sorted
cat ${working_dir}/output2 | sort -u > ${working_dir}/output2-sorted

diff ${working_dir}/output1-sorted ${working_dir}/output2-sorted > ${working_dir}/output-diff 
if [ $? -gt 0 ]; then
    echo "FAIL"
    RETVAL=1
else
    echo "OK"
fi 

/etc/init.d/bdii stop

if [ ${RETVAL} -eq 1 ]; then
    echo "Test Failed"
    echo "See ${working_dir}/output-diff for more details"
    exit 1
else
    rm -rf ${working_dir}
    echo "Test Passed"
    exit 0
fi
