#!/bin/bash
#
# About: OpenMediaVault integration script for Microsoft Active Directory or SAMBA 4
# Author: Eduardo Jonck, liberodark
# Thanks : 
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

log_file="/var/log/join_ad.log"
backtitle="SCRIPT FOR INTEGRATING OPENMEDIAVAULT TO ACTIVE DIRECTORY"


whiptail --title 'Welcome!' \
         --backtitle "$backtitle" \
         --msgbox '\n                    Version: 1.0\n               Author: Eduardo Jonck & liberodark\n          Email: eduardo@eduardojonck.com\n\nWelcome to the OpenMediaVault integration script for Active Directory.\n\nDuring the integration, some questions will be asked.\n\nExtremely important to answer them correctly.
		\n\n\n' \
		20 60

if (whiptail --title "Attention!!!!" \
             --backtitle "$backtitle" \
             --yes-button "Yes" --no-button "No" --yesno "The settings below must be ok before proceeding: \n\n * Static IP address already defined; \n * Server name; \n * SMB settings as factory default. \n\n Are these settings ok?" \
			   20 60) then


#Testar sem o servidor tem acesso a internet para instalar os pacotes de dependencias
clear
echo -e "\033[01;32m##########################################################################\033[01;37m"
echo -e "\033[01;32m## Testing OpenMediaVault communication with the Internet, wait....  ###\033[01;37m"
echo -e "\033[01;32m##########################################################################\033[01;37m"
ping -q -c3 google.com &>/dev/null

if [ $? -eq 0 ] ; then

        whiptail --title "Internet Communication Test" \
				 --backtitle "$backtitle" \
                 --msgbox "The OpenMediaVault server has internet access, press OK to proceed." \
				 --fb 10 50

else
		
        whiptail --title "Internet Communication Test" \
				 --backtitle "$backtitle" \
                 --msgbox "The OpenMediaVault server is without internet access. Review the network settings and run this script again." \
				 --fb 20 50
  exit
fi



(
c=5
while [ $c -ne 1 ]
    do
        echo $c
        echo "###"
        echo "$c %"
        echo "###"
        ((c+=95))
        sleep 1

if [ -f /etc/krb5.conf ];
        then
                echo
        else
	export DEBIAN_FRONTEND=noninteractive
        apt-get -yq install ntpdate krb5-user krb5-config winbind samba samba-common smbclient cifs-utils libpam-krb5 libpam-winbind libnss-winbind > $log_file 2>/dev/null
        fi

break
done
) |
whiptail --title "Installation of dependencies" \
         --backtitle "$backtitle" \
         --gauge "Wait for the installation of the dependencies ...." 10 60 0



hostname_ad=$(whiptail --title "Active Directory Server name information" \
                       --backtitle "$backtitle"	\
                       --inputbox "Enter the name of the Active Directory server.\n\nEx: ad-server" \
					   --fb 15 60 3>&1 1>&2 2>&3)
while [ ${#hostname_ad} = 0 ]; do
[ $? -ne 0 ] & exit
       done

ip_srv_ad=$(whiptail --title "Inform AD Server IP" \
                     --backtitle "$backtitle" \
                     --inputbox "Enter the IP address of the Active Directory server\n\nEx:192.168.1.250" \
 					 --fb 15 60 3>&1 1>&2 2>&3)
while [ ${#ip_srv_ad} = 0 ]; do
[ $? -ne 0 ] & exit
       done

dominio_ad=$(whiptail --title "Domain Configuration for Integration" \
                      --backtitle "$backtitle" \
                      --inputbox "Enter the domain currently configured in Active Directory.\n\nEx: domain.local" \
 					  --fb 15 60 3>&1 1>&2 2>&3)
while [ ${#dominio_ad} = 0 ]; do
[ $? -ne 0 ] & exit
       done
	   
	   
#Inicia teste de comunicacao entre os servers (PING no IP)
clear
echo -e "\033[01;32m###################################################################\033[01;37m"
echo -e "\033[01;32m## Testing the PING on the IP of the informed AD server, wait....  ###\033[01;37m"
echo -e "\033[01;32m###################################################################\033[01;37m"
ping -q -c3 "$ip_srv_ad" &>/dev/null

if [ $? -eq 0 ] ; then

        whiptail --title "Communication Test (PING)" \
				 --backtitle "$backtitle" \
                 --msgbox "The PING on the IP address of the AD server was successful, press OK to proceed." \
 				 --fb 10 50
else

        whiptail --title "Communication Test (PING)" \
		         --backtitle "$backtitle" \
                 --msgbox "PING at the IP address of the AD server was not possible. Review the network settings and run this script again." \
				 --fb 20 50
  exit
fi

#Coleta dados do servidor OMV
ip_srv_omv=$(whiptail --title "OpenMediaVault IP information" \
                      --backtitle "$backtitle" \
                      --inputbox "Which OpenMediaVault IP address do you want to communicate with AD?:" \
   					  --fb 10 60 3>&1 1>&2 2>&3)
while [ ${#ip_srv_omv} = 0 ]; do
[ $? -ne 0 ] & exit
       done

#Alterar nome do arquivo /etc/hostname sem o dominio
change_hostname_samba=$(cat /etc/hostname |cut -d '.' -f 1)
echo "$change_hostname_samba" > /etc/hostname

#Coleta novo hostname
hostname_samba=$(cat /etc/hostname)
netbios_dc=$(echo "$dominio_ad" |cut -d '.' -f 1)

#Apontamento de nomes diretamente no arquivo hosts
echo "$ip_srv_omv"   "${hostname_samba,,}"   "${hostname_samba,,}"."${dominio_ad,,}" > /etc/hosts
echo "$ip_srv_ad"   "${hostname_ad,,}"   "${hostname_ad,,}"."${dominio_ad,,}" >> /etc/hosts

#Ajusta os dominios no resolv.conf
if [ ! -f /etc/resolv.conf.bkp ]; then
cp /etc/resolv.conf /etc/resolv.conf.bkp
fi

echo search "$dominio_ad" > /etc/resolv.conf
echo nameserver "$ip_srv_ad" >> /etc/resolv.conf
echo nameserver 208.67.222.222 >> /etc/resolv.conf
echo nameserver 8.8.8.8 >> /etc/resolv.conf

#Ajusta arquivos Kerberos
if [ ! -f /etc/krb5.conf.bkp ]; then
cp /etc/krb5.conf /etc/krb5.conf.bkp
fi

echo "[logging]
default = FILE:/var/log/krb5libs.log
kdc = FILE:/var/log/krb5kdc.log
admin_server = FILE:/var/log/kadmind.log


[libdefaults]
ticket_lifetime = 24000
default_realm = ${dominio_ad^^}
dns_lookup_realm = false
dns_lookup_kdc = true
forwardable = true

[realms]
${dominio_ad^^} = {
kdc = $ip_srv_ad
admin_server = $ip_srv_ad
default_domain = ${dominio_ad,,}
}

[domain_realm]
.${dominio_ad,,} = ${dominio_ad^^}
${dominio_ad,,} = ${dominio_ad^^}" > /etc/krb5.conf


#Configura o NSSWITCH - /etc/nsswitch.conf
if [ ! -f /etc/nsswitch.conf.bkp ]; then
cp /etc/nsswitch.conf /etc/nsswitch.conf.bkp
fi

echo "passwd:         compat winbind
group:          compat winbind
shadow:         compat
gshadow:        files

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis" > /etc/nsswitch.conf

#Para os servicos e syncroniza a hora entre o OMV com o AD
(
c=5
while [ $c -ne 15 ]
    do
        echo $c
        echo "###"
        echo "$c %"
        echo "###"
        ((c+=45))
        sleep 1


echo "$c"
        echo "###"
        echo "$c %"
        echo "###"
        ((c+=90))
        sleep 1
        ntpdate -u a.ntp.br >> $log_file

break
done
) |
whiptail --title "Synchronize date and time between servers" \
         --backtitle "$backtitle" \
         --gauge "Synchronizing date and time between servers. Wait...." 10 60 0

#Faz backup do arquivo config.xml original
if  [ ! -f /etc/openmediavault/config.xml.bkp ]; then
cp /etc/openmediavault/config.xml /etc/openmediavault/config.xml.bkp
else
cat /etc/openmediavault/config.xml.bkp > /etc/openmediavault/config.xml
fi

#### Gera o arquivo smb customizado para integracao
echo "<extraoptions> security = ads
realm = ${dominio_ad^^}
client signing = yes
client use spnego = yes
kerberos method = secrets and keytab
obey pam restrictions = yes
protocol = SMB3
netbios name = ${hostname_samba^^}
password server = *
encrypt passwords = yes
winbind uid = 10000-20000
winbind gid = 10000-20000
winbind enum users = yes
winbind enum groups = yes
winbind use default domain = yes
winbind refresh tickets = yes
idmap config ${netbios_dc^^} : backend  = rid
idmap config ${netbios_dc^^} : range = 1000-9999
Idmap config *:backend = tdb 
idmap config *:range = 85000-86000 
template shell = /bin/sh
lanman auth = no
ntlm auth = yes
client lanman auth = no
client plaintext auth = No
client NTLMv2 auth = Yes </extraoptions>" > /tmp/smb.tmpl

#Variavel para coleta da linha da tag <extraoptions> do samba para a escrita posterior pelo sed
line_filter=$(cat /etc/openmediavault/config.xml |grep -n homesbrowseable |cut -d: -f1)
line_edit=$(($line_filter+1))
sed -i "$line_edit d" /etc/openmediavault/config.xml &>/dev/null

#Inverte as linhas do arquivo smb customizado para o while escrever corretamente
tac /tmp/smb.tmpl > /tmp/smb.extra

#Escreve as linhas do SMB customizado dentro do arquivo config.xml na tag <extraoptions> do samba
while read -r linha
do
sed  -i "/homesbrowseable/a ${linha}" /etc/openmediavault/config.xml &>/dev/null
done < /tmp/smb.extra
rm -rf /tmp/smb.extra
rm -rf /tmp/smb.tmpl

#Ativa o serviço samba se estiver desativado
#Captura a linha <smb> para troca da linha posterior
line_smb=$(cat /etc/openmediavault/config.xml |grep -n "<smb>" |cut -d: -f1)
line_edit_smb=$(($line_smb+1))
sed -i "$line_edit_smb s/.*/<enable>1<\/enable>/" /etc/openmediavault/config.xml &>/dev/null

#Substitui o atual WorkGroup pelo do AD
#Captura a linha e troca os dados da linha
line_workgroup=$(cat /etc/openmediavault/config.xml |grep -n "<workgroup>" |cut -d: -f1)
sed -i "$line_workgroup s/.*/<workgroup>${netbios_dc^^}<\/workgroup>/" /etc/openmediavault/config.xml &>/dev/null

#Comandos para replicar as configuracoes para o SAMBA
omv-salt deploy run samba &>/dev/null

#Inicia teste de comunicacao entre os servers (PING no DNS)
clear
echo -e "\033[01;32m#####################################################################\033[01;37m"
echo -e "\033[01;32m## Testing the PING on the name of the informed AD server, wait.... ####\033[01;37m"
echo -e "\033[01;32m#####################################################################\033[01;37m"
ping -q -c3 "${hostname_ad,,}"."${dominio_ad,,}" &>/dev/null

if [ $? -eq 0 ] ; then

        whiptail --title "DNS Communication Test" \
		         --backtitle "$backtitle" \
                 --msgbox "The PING on the AD server name was successful, press OK to proceed." \
 				 --fb 10 50
else

        whiptail --title "DNS Communication Test" \
		         --backtitle "$backtitle" \
                 --msgbox "PING in the name of the AD server was not possible. Review the network settings and run the script again." \
				 --fb 20 50
     exit
fi

#Informa a Senha do usario com direitos de administrador
admin_user=$(whiptail --title "Active Directory user" \
                      --backtitle "$backtitle" \
                      --inputbox "Inform the user with Active Directory Administrator rights:" \
 					  --fb 10 60 3>&1 1>&2 2>&3)
while [ ${#admin_user} = 0 ]; do
[ $? -ne 0 ] & exit
       done

#Informa a Senha do usuário com direitos de administrador
admin_pass=$(whiptail --title "Active Directory user password" \
                      --backtitle "$backtitle" \
                      --passwordbox "Enter user password:" \
					  --fb 10 60 3>&1 1>&2 2>&3)
while [ ${#admin_pass} = 0 ]; do
[ $? -ne 0 ] & exit
       done
	   
(
c=5
while [ $c -ne 20 ]
    do
        echo $c
        echo "###"
        echo "$c %"
        echo "###"
        ((c+=30))
        sleep 1
        net ads join -U"$admin_user"%"$admin_pass" --request-timeout 10 &>/dev/null

echo "$c"
        echo "###"
        echo "$c %"
        echo "###"
        ((c+=60))
        sleep 1
	systemctl restart smbd && systemctl restart nmbd &>/dev/null
		
echo "$c"
        echo "###"
        echo "$c %"
        echo "###"
        ((c+=80))
        sleep 1
	systemctl restart winbind &>/dev/null
	
break
done
) |
whiptail --title "Server Integration" \
         --backtitle "$backtitle" \
         --gauge "Wait for the servers to be integrated and synchronized ...." 10 60 0 


#Inicia teste da Integracao
clear
echo -e "\033[01;32m############################################################\033[01;37m"
echo -e "\033[01;32m### Testing the server integration, wait......  ###\033[01;37m"
echo -e "\033[01;32m############################################################\033[01;37m"
sleep 5
testjoin=$(net ads testjoin | cut -f3 -d " ")

if  [ "$testjoin" = OK ] ; then
        whiptail --title "Integration Test" \
		 --backtitle "$backtitle" \
                 --msgbox "Server integration performed successfully.\n\nPress OK to quit." \
				 --fb 20 50
		clear
		systemctl restart openmediavault-engined
else

        whiptail --title "Integration Test" \
			 --backtitle "$backtitle" \
		         --msgbox "The integration of the servers failed. Please run the script again and review your responses." \
				 --fb 20 50
  exit
fi

#Fecha o if inicial da tela de boas vindas.
	else
 exit
fi
