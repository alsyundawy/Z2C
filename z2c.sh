#!/bin/bash

# Developed by Anahuac de Paula Gil <anahuac@anahuac.eu> @2023
# Licensed unde GPL V3

version="1.0.1"
error_message="printf '\e[1;31m%s\e[0m\n'"

echo "Starting Z2C"
mkdir -p export

# User
if [ -d /opt/zextras ] ; then 
	if [ "$(whoami)" != "zextras" ] ; then
		$error_message "ERROR: Z2C must run as zextras user"
		exit 1
	fi
fi
if [ -d /opt/zimbra ] ; then
	if [ "$(whoami)" != "zimbra" ] ; then
		$error_message "ERROR: Z2C must run as zimbra user"
		exit 1
	fi
fi

# Just for single-server
single_or_multi=`zmprov gas mailbox | wc -l`
if [ "$single_or_multi" -gt 1 ] ; then
	$error_message "ERROR: Z2C was dont to migrate ONLY single-servers"
	exit 1
fi

# Loading variables
source ~/bin/zmshutil
zmsetvars

DOMS=`ldapsearch -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -b '' -LLL '(&(!(zimbraIsSystemResource=TRUE))(objectClass=zimbraDomain))' | grep zimbraDomainName | cut -d" " -f2`

# ACCOUNTS ------------------------------------------------------------------
echo "Exporting accounts..."
>export/accounts.ldif
for DOM in $DOMS ; do
       mkdir -p export/$DOM
       dom_base="ou=people,dc=`echo $DOM | sed s/\\\./,dc=/g`"
       ldapsearch -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -b $dom_base -LLL "(&(!(zimbraIsSystemResource=TRUE))(objectClass=zimbraAccount))" | tee export/$DOM/accounts_$DOM.ldif >> export/accounts.ldif
done
# ---------------------------------------------------------------------------

# QUOTAS --------------------------------------------------------------------
echo "Exporting quotas..."
zmprov getQuotaUsage `zmhostname` > /tmp/z2z_quotas.txt
>export/script_import_quota.txt
>export/users.txt
for DOM in $DOMS ; do
	mkdir -p export/$DOM
	>export/$DOM/script_import_quota_$DOM.txt
	>export/$DOM/users_$DOM.txt

	grep "@$DOM " /tmp/z2z_quotas.txt | sort > export/$DOM/quotas_$DOM.txt
	oldIFS=$IFS
	IFS='
'
	for USERQUOTA_DATA in `cat export/$DOM/quotas_$DOM.txt` ; do
		DOM_USER=`echo $USERQUOTA_DATA | cut -d" " -f1`
		DOM_USERQUOTA=`echo $USERQUOTA_DATA | cut -d" " -f2`
		echo "ma $DOM_USER zimbraMailQuota $DOM_USERQUOTA" | tee -a export/$DOM/script_import_quota_$DOM.txt >> export/script_import_quota.txt
		echo "$DOM_USER" | tee -a export/$DOM/users_$DOM.txt >> export/users.txt
	done
	IFS=$oldIFS
done
# ---------------------------------------------------------------------------

# ALIASES -------------------------------------------------------------------
echo "Exporting aliases..."
> export/aliases.ldif
for DOM in $DOMS ; do
	mkdir -p export/$DOM
	dom_base="ou=people,dc=`echo $DOM | sed s/\\\./,dc=/g`"
	ldapsearch -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password  -b $dom_base -LLL '(&(!(uid=root))(!(uid=postmaster))(objectclass=zimbraAlias))' | tee export/$DOM/aliases_$DOM.ldif >> export/aliases.ldif
done
# ---------------------------------------------------------------------------

# LISTS ---------------------------------------------------------------------
echo "Exporting lists..."
>export/lists.ldif
for DOM in $DOMS ; do
	mkdir -p export/$DOM
	dom_base="ou=people,dc=`echo $DOM | sed s/\\\./,dc=/g`"
	ldapsearch -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -b $dom_base -LLL "(|(objectclass=zimbraGroup)(objectclass=zimbraDistributionList))" | tee export/$DOM/lists_$DOM.ldif >> export/lists.ldif
done
# ---------------------------------------------------------------------------

# Dealing with Hostname -----------------------------------------------------
read -p "Destiny server will have a different Hostname (y/n)? " new_hostname_menu
case "$new_hostname_menu" in
	y|Y|yes )
		read -p "Type new Hostname: " new_hostname
		if [ -z "$new_hostname" ] ; then echo "host can't be empty..." ; exit 1 ; fi
		echo "Replacing hostname..."
		sed -i s/$zimbra_server_hostname/$new_hostname/g export/accounts*.ldif
		sed -i s/$zimbra_server_hostname/$new_hostname/g export/lists*.ldif
		for DOM in $DOMS ; do
			sed -i s/$zimbra_server_hostname/$new_hostname/g export/$DOM/accounts*.ldif
		        sed -i s/$zimbra_server_hostname/$new_hostname/g export/$DOM/lists*.ldif
		done
	;;
	n|N )
		echo "Doing nothing about hostname..."
	;;
	*)
		echo "Doing nothing about hostname..."
	;;
esac
# ---------------------------------------------------------------------------

# Mailboxes scripts ---------------------------------------------------------
echo "Creating mailboxes export and restore scripts..."
read -p "Type where mailboxes dumps will be exported to: " export_path
if [ -z $export_path ] ; then echo "Export path can't be empty" ; exit 1 ; fi

mbox_list=`zmprov -l gaa | grep -v -E "admin|virus-|ham.|spam.|galsync"`
>export/script_export_FULL.sh ; >export/script_import_FULL.sh ; >export/script_export_TRASH.sh ; > export/script_import_TRASH.sh
for mailbox in `echo $mbox_list` ; do

	# export/script_export_FULL.sh
	# -----------------------------------------------------------------------------------------
	echo "zmmailbox -z -m $mailbox -t 0 getRestURL \"/Calendar/?fmt=tgz\" > $export_path/Calendar-$mailbox.tgz" >> export/script_export_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 getRestURL \"/Contacts/?fmt=tgz\" > $export_path/Contacts-$mailbox.tgz" >> export/script_export_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 getRestURL \"/Emailed Contacts/?fmt=tgz\" > $export_path/Emailed-Contacts-$mailbox.tgz" >> export/script_export_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 getRestURL \"/Tasks/?fmt=tgz\" > $export_path/Tasks-$mailbox.tgz" >> export/script_export_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 getRestURL \"//?fmt=tgz\" > $export_path/$mailbox.tgz" >> export/script_export_FULL.sh
	chmod +x export/script_export_FULL.sh

	# export/script_import_FULL.sh
	# -----------------------------------------------------------------------------------------
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/Calendar-$mailbox.tgz" >> export/script_import_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/Contacts-$mailbox.tgz" >> export/script_import_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/Emailed-Contacts-$mailbox.tgz" >> export/script_import_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/Tasks-$mailbox.tgz" >> export/script_import_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/$mailbox.tgz" >> export/script_import_FULL.sh
	chmod +x export/script_import_FULL.sh

	# export/script_export_TRASH.sh
	# -----------------------------------------------------------------------------------------
	echo "zmmailbox -z -m $mailbox -t 0 gru \"//Trash?fmt=tgz\" > $export_path/$mailbox-Trash.tgz" >> export/script_export_TRASH.sh
	chmod +x export/script_export_TRASH.sh

	# export/script_export_TRASH.sh
	# -----------------------------------------------------------------------------------------
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/$mailbox-Trash.tgz" >> export/script_import_TRASH.sh
	chmod +x export/script_import_TRASH.sh

	# export/$mailbox_dom/script_export_FULL.sh
	# -----------------------------------------------------------------------------------------
	mailbox_dom=`echo $mailbox | cut -d\@ -f2` ; mkdir -p export/$mailbox_dom
	echo "zmmailbox -z -m $mailbox -t 0 getRestURL \"/Calendar/?fmt=tgz\" > $export_path/Calendar-$mailbox.tgz" >> export/$mailbox_dom/script_export_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 getRestURL \"/Contacts/?fmt=tgz\" > $export_path/Contacts-$mailbox.tgz" >> export/$mailbox_dom/script_export_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 getRestURL \"/Emailed Contacts/?fmt=tgz\" > $export_path/Emailed-Contacts-$mailbox.tgz" >> export/$mailbox_dom/script_export_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 getRestURL \"/Tasks/?fmt=tgz\" > $export_path/Tasks-$mailbox.tgz" >> export/$mailbox_dom/script_export_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 getRestURL \"//?fmt=tgz\" > $export_path/$mailbox.tgz" >> export/$mailbox_dom/script_export_FULL.sh
	chmod +x export/$mailbox_dom/script_export_FULL.sh

	# export/$mailbox_dom/script_import_FULL.sh
	# -----------------------------------------------------------------------------------------
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/Calendar-$mailbox.tgz" >> export/$mailbox_dom/script_import_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/Contacts-$mailbox.tgz" >> export/$mailbox_dom/script_import_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/Emailed-Contacts-$mailbox.tgz" >> export/$mailbox_dom/script_import_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/Tasks-$mailbox.tgz" >> export/$mailbox_dom/script_import_FULL.sh
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/$mailbox.tgz" >> export/$mailbox_dom/script_import_FULL.sh
	chmod +x export/$mailbox_dom/script_import_FULL.sh

	# export/script_export_TRASH.sh
	# -----------------------------------------------------------------------------------------
	echo "zmmailbox -z -m $mailbox -t 0 gru \"//Trash?fmt=tgz\" > $export_path/$mailbox-Trash.tgz" >> export/$mailbox_dom/script_export_TRASH.sh
	chmod +x export/$mailbox_dom/script_export_TRASH.sh

	# export/script_export_TRASH.sh
	# -----------------------------------------------------------------------------------------
	echo "zmmailbox -z -m $mailbox -t 0 postRestURL -u \"https://localhost:7071\" \"//?fmt=tgz&resolve=skip\" $export_path/$mailbox-Trash.tgz" >> export/$mailbox_dom/script_import_TRASH.sh
	chmod +x export/$mailbox_dom/script_import_TRASH.sh

done


echo "Z2C has done it all..."
echo "Copy it all Z2C to the destination server and run restore.sh"
echo ""
