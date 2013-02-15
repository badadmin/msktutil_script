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

about
================

These scripts grew out of my frustration at the lack of a concise 
solution to join Linux and AIX servers to a Windows 2003 RC2 or 200 R2 Active 
Directory domain using native-ish tools.  There are lots of resources online 
and off that kinda sorta maybe do this.  But they are always incomplete.  This 
is my attempt to pull together a lot of different ideas and make them all work.
As such, I can not and do not take full credit for this.  Yes, I wrote the main
msktutil_core.sh script.  No, I cannot take credit for writing the k5start_ldap, 
or krb5-ticket-renew.sh.  Changed one just a little but that's it.  Also, other
sources had different goals and I embraced them.  All lot of the ideas and 
direction came from this post and it's follow-ups by Mark R. Bannister:

    http://technicalprose.blogspot.com/2011/10/linux-integration-with-active-directory.html

Yes, there are 3rd party solutions like Quest Authentication Services and 
Centrify Active Directory Bridging and Centrify Express and BeyondTrust 
PowerBroker Identity Services for Active Directory Bridging.  All of these have 
benefits and disadvantages.  With the exception of Centrify Express, cost is 
the greatest.  I like free stuff.

Samba is often touted as the *right tool for the job* but it, too, has its 
advantages and disadvantages.  Part of goal in pulling all of this together 
and in writing this stupid long bash script was to overcome the problems we 
faced at work with a poorly implemented Samba solution.  Please note that I 
said *poorly implemented solution * and not that Samba itself was poorly 
implemented.  TL;DR - Samba had to go and this scripts will uninstall it by 
default unless you make some changes.  Don't take it personally.

I also have a strong LDAP and Active Directory background and it 
just so happens that we could *not* stand-up an OpenLDAP server and create a 
trust between it and the existing corporate Active Directory domain.  As such, 
I knew what I needed to be able to do on the Linux-side and what I needed to 
add to user objects on the Active Directory-side to make this work.  Don't 
worry; there are no schema changes happening.  All the fields that need to be 
updated in Active Directory exist post-Windows 2003 RC2 and 2008 R2.

The driver behind this is msktutil ... :

    http://code.google.com/p/msktutil/

... if you aren't familiar; become so.  It's an outstanding tool.

The other tool being levergaed is kstart ... :

    http://www.eyrie.org/~eagle/software/kstart/

... again, a good place to start if you are unfamiluar.

running msktutil_core
================

In the CORE folder, you'll find two files ... :

    msktutil_core.conf
	msktutil_core.sh

The msktutil_core.conf file contains the variable settings used by 
msktutil_core.sh.  This is were you will need to set a number of variables
specific to your environment.  These are ... :

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

