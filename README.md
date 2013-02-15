msktutil_script
================

Scripts to back-up and replace multiple files on a RHEL5 or RHEL5-clone server
so that it will use Kerberos authentication from a Windows 2003 RC2 or 2008 R2
Active Directory Domain.

The script leverages msktutil to create and manage the schema objects in Active
 Directory.

The script requires that you have an account in the Active Directory domain 
with the administrative rigth to join servers to the domain and to manage 
servers objects.  In other words, a Domain Administrator account.

This script does *not* create new or modify existing users with the schema 
attributes and values required to properly authenticate from the Linux server 
to Active Directory.

disclaimer
================

These scripts will fundamentally change the behavior of your server, or, at 
least it will attempt to.  Please do not run this against a production server 
or any server that you care about until you have completely tested and vetted
the results against your requirements and the outcome arrived at.

The main msktutil_core.sh script will make backup copies of all the impacted 
files prior to chnaging them.  It does not, however, provide the means to 
roll-back the changes made by the authconfig command.

Finally, if this scripts causes you untold amounts of financial loss, the 
dissolution of your marriage, your dog to die, your server to explode, your 
Active Directory domain to spiral out of control in a fiery Nordic dirge ... 
I am not resposible.  You have been cautioned.

running msktutil_core
================

In the CORE folder, you'll find two files:

    msktutil_core.conf
	msktutil_core.sh

The msktutil_core.conf file contains the variable settings used by 
msktutil_core.sh.  This is were you will need to set a number of variables
specific to your environment.  These are:

    DOMAIN_NAME_01
	DOMAIN_NAME_02
	DC_01_IP
	DC_01_HOSTNAME
	DC_01_FQDN
	DC_02_IP
	DC_02_HOSTNAME
	DC_02_FQDN
	DESCRIPTION
	IDMAPD_DOMAIN
	IDMAPD_REALMS
	RHEL5_MAIN_DESCRIPTION
	NFSV4_MAIN_DESCRIPTION
	AUTOFS_MASTER_MAP_NAME
	AUTOFS_LDAP_URI
	AUTOFS_SEARCH_BASE

... the remaining values can be left at their defaults but you should, of 
course, review these and ensure that the settings match your requirements.