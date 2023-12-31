# Z2C
Zimbra to Carbonio Migration


# Z2C ( Anahuac's Zimbra To Carbonio )

## Author

Developed by Anahuac de Paula Gil <anahuac@anahuac.eu> @2023

- Original blob post and probably updates: [https://www.anahuac.eu/zimbra-to-carbonio-z2c/](https://www.anahuac.eu/zimbra-to-carbonio-z2c/).

## License

Licensed under GPL V3

## INSTALLATION

Z2C is a quite simple pair of scripts to export LDAP data from an origin Zimbra or Carbonio server and import it on a brand new Zimbra or Carbonio server. It's goal is to migrate accounts and help to dump and restore mailboxes from one server to another.

As simple as it is, there is no need for install anything. Just run the scripts:

- 1 - `z2c.sh` to export it all from the original server
- 2 - copy a `Z2C` folder to the new server
- 3 - fix its permissions on the new server
- 4 - `restore.sh` to import it on the new server

Those steps will export users, aliases and lists from the origin server and import it to the destination server.

### MAILBOXES

Once you have all domains, accounts, aliases and list imported on the new server it's time to dump mailboxes on the original server, copy it to the new one and then retore it there.

Z2C makes it pretty easy for you, creating a full set of scripts:

- script_export_FULL.sh   : A list of zmmailbox commands to dump all mailboxes;
- script_export_TRASH.sh  : A list of zmmailbox commands to dump the Trash folder, because it's not dumped on the regular command and some users can't live without it's Trash =)
- script_import_FULL.sh   : A list of zmmailbox commands to restore all mailboxes;
- script_import_TRASH.sh  : A list of zmmailbox commands to restore the Trash folder, because it's not restored on the regular command and some users can't live without it's Trash =)￼
- script_import_quota.txt : A list of zmprov commands to restore all accounts quotas if you need it;
- users.txt               : A list of users to make it at hand in case you want to script anything #nerdfellings

### PARALLEL

You may consider to install and run those scripts using parallel to make dumps and restores faster. 
Those scripts are great but it may take quite a long time to run it if you have hundreds or thousands of accounts, so be able to run many at the same time in a non stop way it's faster, by far.

Just take care not to do too many at the same time, your server may not be able to deal with the overload. We suggest you to use between 3 and 5 simultaneously dumps/restore, but feel free to test it out.

This is how you use it:

```
parallel -j4 < script
```

- `j4` : where 4 is the number of processes it will run at the same time;
- `script` : the name of that file with the list of commands you wana it to process

### TIPS&TRICKS

Sometimes zmmailbox aborts processing with a "timeout" error despite the fact we're using `-t0` flag option.
The workaround it it to change socket_so_timeout option to a very high time before start importing those mailboxes dumps and restore it's default value when it's over. So here you have it:

```
zmlocalconfig -e socket_so_timeout=99999999
zmlocalconfig --reload
```

Then import it all

To restore default values do:
```
zmlocalconfig -e socket_so_timeout=30000
zmlocalconfig --reload
```

### ENJOY !

Whish it helps!
Enjoy!
