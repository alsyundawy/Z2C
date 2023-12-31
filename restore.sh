#/bin/bash

# Developed by Anahuac de Paula Gil <anahuac@anahuac.eu> @2023
# Licensed unde GPL V3

version="1"
error_message="printf '\e[1;31m%s\e[0m\n'"
session=`date +"%d_%b_%Y-%H-%M"`
session_log="z2c-$session.log"

# Loading variables
source ~/bin/zmshutil
zmsetvars

# User
if [ -d /opt/zextras ] ; then
	if [ "$(whoami)" != "zextras" ] ; then
		$error_message "ERROR: restore.sh must run as zextras user"
		exit 1
        fi
fi
if [ -d /opt/zimbra ] ; then
	if [ "$(whoami)" != "zimbra" ] ; then
	        $error_message "ERROR: restore.sh must run as zimbra user"
	        exit 1
	fi
fi

# Hostname match test

ldif_hostname=`grep zimbraMailHost export/accounts.ldif | uniq | awk '{print $2}'`
if [ "$zimbra_server_hostname" != "$ldif_hostname" ]; then
	$error_message "ERROR: local hostname and hostname on ldif files doesn't match!"
	exit 1
fi

# Importing
echo ""
echo "Importing accounts..."
echo "Logs available in $session_log"
echo ""
read -p "Do you want to import one domain or all? (one/all)? " choice
mkdir -p log
case "$choice" in
one )
	read -p "Type the domain you wanna create and import: " domain
	if [ ! -d export/$domain ] ; then
		$error_message "ERROR: domain $domain doesn't exists in \"export\""
		exit 1
	fi
	if [ ! -f export/$domain/accounts_$domain.ldif ] || [ -z export/$domain/accounts_$domain.ldif ] ; then
		$error_message "ERROR: ldif accounts file is empty or doesn't exists"
		exit 1
	fi
	echo "Creating domain $domain..."
	zmprov cd $domain >/dev/null 2>/dev/null

	echo "Importing accounts..."
	ldapadd -c -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -f export/$domain/accounts_$domain.ldif &>> log/$session_log
	echo "Importing aliases..."
	ldapadd -c -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -f export/$domain/aliases_$domain.ldif &>> log/$session_log
	echo "Importing lists..."
	ldapadd -c -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -f export/$domain/lists_$domain.ldif &>> log/$session_log

	echo "Done!"
;;
all )
	read -p "All domains will be created and all accounts imported: (y/N) " doall
	case "$doall" in
		y|Y|yes )
			echo "Creating domains..."
			>/tmp/z2zc_domains
			for domain in  `ls -l export | grep '^d' | tr -s ' ' | cut -d" " -f9` ; do
				echo "cd $domain" >> /tmp/z2zc_domains
			done
			cat /tmp/z2zc_domains | zmprov >/dev/null 2>/dev/null

			echo "Importing accounts..."
			ldapadd -c -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -f export/accounts.ldif &>> log/$session_log
			echo "Importing aliases..."
			ldapadd -c -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -f export/aliases.ldif &>> log/$session_log
			echo "Importing lists..."
			ldapadd -c -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -f export/lists.ldif &>> log/$session_log

			echo "Done!"
		;;
		n|N|no ) exit 0;;
		* ) echo "Leaving..." ;;
	esac
;;
* ) echo "Leaving..." ;;
esac


