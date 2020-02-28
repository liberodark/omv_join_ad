#!/bin/bash
#
# About: OpenMediaVault integration script for Microsoft Active Directory or SAMBA 4
# Author: Eduardo Jonck, liberodark
# Thanks : Jesus Andrade
# License: GNU GPLv3

version="1.0"

echo "Welcome on OMV Join AD Script $version"

#=================================================
# CHECK ROOT
#=================================================

if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

#=================================================
# RETRIEVE ARGUMENTS FROM THE MANIFEST AND VAR
#=================================================

echo "Enter the domain name Ex. EXAMPLE.LOCAL: " ; read DOMAIN
echo "Enter the name of your Domain Controller Ex. dc01.example.local: " ; read DC
echo "Inform the user that will be used as Domain Admin to join the domain: " ; read DOMAINUSER
# Install required packages
apt-get update
apt-get dist-upgrade -y
apt-get install krb5-user krb5-config winbind samba samba-common smbclient cifs-utils libpam-krb5 libpam-winbind libnss-winbind

# Backup Kerberos file
cp /etc/krb5.conf /etc/krb5.conf.ori

# Corrige arquivo Kerberos
echo "[logging]
Default = FILE:/var/log/krb5.log

[libdefaults]
ticket_lifetime = 24000
clock-skew = 300
default_realm = $DOMAIN
dns_lookup_realm = true
dns_lookup_kdc = true

[realms]
$(echo "$DOMAIN")  = {
kdc = $DC
default_domain = $(echo "$DOMAIN" | tr 'A-Z' 'a-z')
admin_server = $DC
}

[domain_realm]
.$(echo "$DOMAIN" | tr 'A-Z' 'a-z') = $DOMAIN
$(echo "$DOMAIN" | tr 'A-Z' 'a-z') = $DOMAIN

[login]
krb4_convert = true
krb4_get_tickets = false" > /etc/krb5.conf

# Fixes the DNS resolution issue and makes winbind users able to log in
cp /etc/nsswitch.conf /etc/nsswitch.conf.ori
echo "passwd:         compat winbind
group:          compat winbind
shadow:         files
gshadow:        files

# hosts:          files mdns4_minimal [NOTFOUND=return] dns myhostname
hosts:          dns files mdns4_minimal [NOTFOUND=return] myhostname
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis" > /etc/nsswitch.conf

# Tests if the DC connection is ok
echo "

Enter the domain administrator password to check the feasibility of joining the domain"
kinit "$DOMAINUSER"
klist

# Add this to Samba Extras to integrate with the domain
echo "Enable samba and add this in the OpenMediaVault samba extras via the graphical interface:

security = ads
realm = $(echo "$DOMAIN")
client signing = yes
client use spnego = yes
kerberos method = secrets and keytab
obey pam restrictions = yes
protocol = SMB3
netbios name = $(hostname | cut -d '.' -f1)
password server = *
encrypt passwords = yes
winbind uid = 10000-20000
winbind gid = 10000-20000
winbind enum users = yes
winbind enum groups = yes
winbind use default domain = yes
winbind refresh tickets = yes
idmap config $(echo "$DOMAIN" | cut -d '.' -f1) : backend  = rid
idmap config $(echo "$DOMAIN" | cut -d '.' -f1) : range = 1000-9999
Idmap config *:backend = tdb 
idmap config *:range = 85000-86000 
template shell    = /bin/sh
lanman auth = no
ntlm auth = yes
client lanman auth = no
client plaintext auth = No
client NTLMv2 auth = Yes" > /tmp/smb.tmp
cat /tmp/smb.tmp

# Request Enter to continue configuration
echo "


After making the change, type Enter: " ; read ENTER

# Integrates with the domain
echo "


Enter the domain administrator password to integrate OpenMediaVault with DC "
net ads join -U "$DOMAINUSER"
net ads testjoin

# Restart services
/etc/init.d/smbd restart
/etc/init.d/winbind restart

# Lists domain users
sleep 3
wbinfo -u

echo "Restart the server and check if users have been successfully added to the graphical interface!"
