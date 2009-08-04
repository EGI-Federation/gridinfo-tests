#!/bin/sh

# Prepare
working_dir=$(mktemp -d)
chown edguser:edguser ${working_dir}

# Configure the BDII
sed "s#/opt/glite/etc/gip#${working_dir}#"  /opt/bdii/etc/bdii.conf > ${working_dir}/bdii.conf
sed -i "s#BDII_READ_TIMEOUT=.*#BDII_READ_TIMEOUT=300#"  ${working_dir}/bdii.conf
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

EOF

wget "http://lcg-bdii-conf.cern.ch/bdii-conf/bdii.conf" -O ${working_dir}/egee-urls.conf 2>/dev/null

cat << EOF > ${working_dir}/provider/egee-provider
#!/bin/sh
/opt/glite/libexec/glite-info-provider-ldap -c ${working_dir}/egee-urls.conf -m local
EOF

chmod +x ${working_dir}/provider/* 

export BDII_CONF=${working_dir}/bdii.conf
/etc/init.d/bdii restart

RETVAL=0
echo "Waiting 180 second for the BDII to start."
sleep 180

echo -n "Testing Top BDII: "
ldapsearch -LLL -x -h $(hostname -f) -p 2170 -b mds-vo-name=local,o=grid dn | perl -pe 'BEGIN { $/ = "" } s/\n //g' > ${working_dir}/output1
ldapsearch -LLL -x -h lcg-bdii -p 2170 -b mds-vo-name=local,o=grid dn | perl -pe 'BEGIN { $/ = "" } s/\n //g' > ${working_dir}/output2

cat ${working_dir}/output1 | sort -u > ${working_dir}/output1-sorted
cat ${working_dir}/output2 | sort -u > ${working_dir}/output2-sorted

diff ${working_dir}/output1-sorted ${working_dir}/output2-sorted > ${working_dir}/output-diff 
if [ $? -gt 0 ]; then
    echo "FAIL"
    RETVAL=1
else
    echo "OK"
fi 

#/etc/init.d/bdii stop

if [ ${RETVAL} -eq 1 ]; then
    echo "Test Failed"
    echo "See ${working_dir}/output-diff for more details"
    exit 1
else
    rm -rf ${working_dir}
    echo "Test Passed"
    exit 0
fi
