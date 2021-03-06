msktutil_script
================

Scripts to back-up and replace multiple files on a RHEL5 or RHEL5-clone server so that it will use Kerberos authentication from a Windows 2003 RC2 or 2008 R2
Active Directory Domain.

The script leverages msktutil to create and manage the schema objects in Active  Directory.

The script requires that you have an account in the Active Directory domain with the administrative rigth to join servers to the domain and to manage 
servers objects.  In other words, a Domain Administrator account.  This script does *not* create new or modify existing users with the schema 
attributes and values required to properly authenticate from the Linux server to Active Directory.

disclaimer
================

These scripts will fundamentally change the behavior of your server, or, at least it will attempt to.  Please do not run this against a production server 
or any server that you care about until you have completely tested and vetted the results against your requirements and the outcome arrived at.  The main 
msktutil_core.sh script will make backup copies of all the impacted files prior to changing them.  It does not, however, provide the means to roll-back the 
changes made by the authconfig command.

Finally, if this scripts causes you untold amounts of financial loss, the dissolution of your marriage, your dog to die, your server to explode, your 
Active Directory domain to spiral out of control in a fiery Nordic dirge ... I am not resposible.

You have been cautioned.

about
================

These scripts grew out of my frustration at the lack of a concise solution to join Linux and AIX servers to a Windows 2003 RC2 or 2008 R2 Active 
Directory domain using native-ish tools.  There are lots of resources online and off that kinda sorta maybe do this.  But they are always incomplete.  This 
is my attempt to pull together a lot of different ideas and make them all work.  As such, I can not and do not take full credit for this.  Yes, I wrote the main
msktutil_core.sh script.  No, I cannot take credit for writing the k5start_ldap, or krb5-ticket-renew.sh.  Changed one just a little but that's it.  Also, other
sources had different goals and I embraced them.  All lot of the ideas and direction came from this post and it's follow-ups by Mark R. Bannister:

[Technical Prose - Linux Integration with Active Directory - Part 1](http://technicalprose.blogspot.com/2011/10/linux-integration-with-active-directory.html)

Yes, there are 3rd party solutions like Quest Authentication Services and Centrify Active Directory Bridging and Centrify Express and BeyondTrust 
PowerBroker Identity Services for Active Directory Bridging.  All of these have benefits and disadvantages.  With the exception of Centrify Express, cost is 
the greatest.  I like free stuff.

Samba is often touted as the *right tool for the job* but it, too, has its advantages and disadvantages.  Part of the goal in pulling all of this together 
and in writing this stupid long bash script was to overcome the problems we faced at work with a poorly implemented Samba solution.  Please note that I 
said *poorly implemented solution * and not that Samba itself was poorly implemented.  The solution was lacking insofar as the person implementing it 
was not concerned with how the Active Directory-side of things worked or, oddly enough, how things like NTP work.  TL;DR - Samba had to go and this scripts 
will uninstall it by default unless you make some changes.  Don't take it personally.

I also have a strong LDAP and Active Directory background and it just so happens that we could *not* stand-up an OpenLDAP server and create a 
trust between it and the existing corporate Active Directory domain.  As such, I knew what I needed to be able to do on the Linux-side and what I needed to 
add to user objects on the Active Directory-side to make this work.  Don't worry; there are no schema changes happening.  All the fields that need to be 
updated in Active Directory exist post-Windows 2003 RC2 and 2008 R2.

**NOTE**:  I don't include any LDIF at this time for making bulk user modifications in Active Directory.  I might include them in the future.  Here are the values 
that matter to you in Active Directory ... :

* loginshell
* gecos
* gid
* gidNumber
* uid
* uidNumber
* unixHomeDirectory

... please see my blog post if you'd like more information ... :

[Configuring Red Hat Enterprise Linux (RHEL) 5 To Authenticate Against LDAP (Microsoft Windows Active Directory 2008 R2) Using Kerberos 5](http://lesserhero.blogspot.com/2012/09/rhel-5-active-directory-and-kerberos.html)

... in fact, that blog post is non-automated version of this process.  Please note, however, that it has not been updated in some time and I have learned a 
few new things about this process while trying to automate it somewhat.

The driver behind this is [msktutil](http://code.google.com/p/msktutil/); if you aren't familiar; become so.  It's an outstanding tool.

The other tool being leveraged is [kstart](http://www.eyrie.org/~eagle/software/kstart/).  Again, a good place to start if you are unfamiliar.

goals
================

*Security*
* No bind user or bind user password required to present in any Linux file!
* No UID\GID randomness.  What is assigned in Active Directory is what is used on the Linux server.
* Nested LDAP Groups.  I am a member of one group ... and the twenty other nested beneath it.  This is good for sudo purposes and a stupid difficult problem in Samba.
* LDAP groups are seen by sudoers.
* **NO ONE** can change an Active Directory user password from the Linux server without knowing the original password.

That last one means that if I, using my Active Directory Domain Administrator account (badadmin_ldap), run this ... :

    [badadmin_ldap@server01]$ passwd luxuser01
	passwd: Only root can specify a user name.
    Password for luxuser01@LUX.INTERNAL: 

... I will still be prompted by Kerberos for your_account' original password.  Why?  Because the Kerberos ticket I am logged in under is only good for me. This will occur if root attempts to do this.  This is important because some solutions, like Quest Authentication Services, allow that ability.  Why?  I don't know.  Always seemed like a compromise between functionality and usabilty and Quest decided to let 
the ability be governed by the consumer' management of the /etc/sudoers file.  Later version may not do allow this.  My involvement peaked at v4.

Additionally, attempting to su to another account has differences as well.  Below, I login as badadmin_ldap and receive a Kerberos ticket from Active Directory.  I then su to user luxuser01 (as allowed with no password per the /etc/sudoers file).  Next, I 
try to change the password for for user luxuser01 as luxuser01 and I am prompted for luxuser01' existing Kerberos 5 password ... :

    [badadmin_ldap@server01]$ whoami         
    badadmin_ldap
    [badadmin_ldap@server01]$ sudo su luxuser01
    [luxuser01@server01]$ whoami
    luxuser01
    [luxuser01@server01]$ passwd
    Changing password for user luxuser01.
    Kerberos 5 Password: 
    passwd: Authentication token manipulation error

... additionally, if I try to su with the users environment I am immediately prompted for their Kerberos 5 password ... :

    [badadmin_ldap@server01$ sudo su - luxuser01
    Password for luxuser01@LUX.INTERNAL: 

... these results are the same if the root user (instead of badadmin_ldap) attempts this.
	
*Computer Domain Membership*
* Join RHEL 5 server (or RHEL 5 clone) to Active Directory domain from the command-line of the Linux server.
* Auto-acquire and populate Kerberos key from Active Directory and from the command-line of the Linux server.
* Allow the computer to automatically change it's password every 30 days (possible only if NFSv4 is **not** being used ... see notes further down)

*Authentication to LDAP*
* Console Login
* SSH\SFTP Login
* HTTP\FTP Login (not implemented yet ... waiting for update to msktutil to better support service accounts directly)

*Authorized Password Changes*
* Force user to change their password at their initial login or after a password has been reset in Active Directory.
* Notify user when their password is approaching expiry or has already expired.
* Honor password policies as set in Active Directory GPO password policies (some of these work, like number of days before user can change password again.  Others, like the password complexity requirements get hung-up on RHEL' password complexity rules and need to be disabled locally to be circumvented).
* Account lock-out per Active Directory policy (lock-out on LDAP server means locked out on domain).
* Allow Active Directory password to be changed from Linux server.

*Other Stuff*
* The krb5-ticket-renew.sh script that gets set-up monitors the state you each user' Kerberos ticket and calls kinit to refresh it periodically.

This is the same kind of behavior that goes on behind the scenes when you are logged in to a Windows server.  Simply calling kinit as *user* doesn't require a password if the user has a currently valid Kerberos ticket.  It merely tells the Active Directory domain 
controller that *user* is still logged in and still needs their ticket.  This good because the alternative is that *user* needs to remember to do this themselves every few hours.  When the Kerberos ticket for *user* is truly about to expire, the script will 
prompt *user* to re-enter their Active Directory password via kinit.  It will also delete expired Kerberos tickets.

**NOTE**:  The krb5-ticket-renew.sh script can be setup to email users when they are in the final few hours of their Kerberos ticket lifetime and to automatically log users out after *X* amount of time if the user does not re-enter their password.  The script 
is not currently setup to do this.  One of two things will happen ... :

* The user will be prompted to re-enter the Kerberos password if the ticket is still within it's renewable lifetime.
* The user will be prompted to request a new Kerberos tickket if their current ticket has been deleted.

... if the krb5-ticket-renew.sh script is not running, the user will get a cryptic Kerberos error message and will need to know that they should then do this to update their Kerberos ticket ... :

    [badamdin@server01]$ kinit badadmin
	Kerberos Password:

todo
================

* Implement nsupdate to allow dynamic DNS between Linux and Active Directory.
* Expand to cover RHEL 6 and Debian\Ubuntu.
* Break script up to be more modular and add some menu functionality.
* Add a restore process to revert as many changes as possible to allow roll-back.
* Add Postfix or Sendmail configuration to allow emailed results and alerts.

Please let me know how I can improve script.

running msktutil_core
================

In the CORE folder, you'll find two files ... :

    msktutil_core.conf
	msktutil_core.sh

The msktutil_core.conf file contains the variable settings used by msktutil_core.sh.  This is were you will need to set a number of variables specific to your environment.  These are ... :

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

... the remaining values can be left at their defaults but you should, of course, review these and ensure that the settings match your requirements.

My environment does not allow for direct internet access so the script does not at this time make wget options available.  You will need to download and save the following (per your architecture) prior to execution ... :

* [msktutil-0.4.2-1.el5.i386.rpm - RHEL5 i386](http://dl.fedoraproject.org/pub/epel/5/i386/msktutil-0.4.2-1.el5.i386.rpm)
* [msktutil-0.4.2-1.el5.x86_64.rpm - RHEL5 x86_64](http://dl.fedoraproject.org/pub/epel/5/x86_64/msktutil-0.4.2-1.el5.x86_64.rpm)
* [kstart-4.1-2.el5.i386.rpm - RHEL5 i386](http://dl.fedoraproject.org/pub/epel/5/i386/kstart-4.1-2.el5.i386.rpm)
* [kstart-4.1-2.el5.x86_64.rpm - RHEL5 x86_64](http://dl.fedoraproject.org/pub/epel/5/x86_64/kstart-4.1-2.el5.x86_64.rpm)
* [Fedora EPEL Repository GPG Key - RPM-GPG-KEY-EPEL](https://fedoraproject.org/static/217521F6.txt)

... the last one, EPEL Repository GPG Key, can be found under RPM > RHEL_5 > EPEL_REPO_KEY.  If Fedora decides tomorrow to change this then it will no longer work.

The remaining RPMs will need to be download for your architecture (RHEL 5 i386 or x86_64) to RPM > RHEL_5 > i386 or RPM > RHEL_5 > x86_64.  As mentioned earlier, future verisons will support RHEL 6 and RHEL 6 clones.

**NOTE**:  The script currently expects to find these exact versions of msktutil and kstart.  If you download them in the future and find that the version has changed then you will need to modify msktutil_core.sh.
Anyone that feels like telling me how to future-proof this please do.

Once you have all your files in place on server01 (or an NFS share that you are currently in); run this to convert server01 to a Kerberos-enabled member of the Active Directory domain (just what we always wanted, right?) ... :

    [badadmin@server01]$ sudo su -
	[root@server01]# cd CORE
    [root@server01]# chmod 755 *.sh
    [root@server01]# ./msktutil_core.sh server01

... after a couple of lines, you'll be prompted for the *username* of an Active Directory account that has the ability to join a computer to the domain.  Enter *just* the username.  Not domain\username.  Not username@domain.  Just.  The.  Username.  And hit <ENTER>.
It'll look like this:

    <<< BEGIN MSKTUTIL_CORE INSTALL >>>
    [INFO] ... INSTALL START TIME: 20:40:24-EST
    
    ##################################################
    #                                                #
    #     WELCOME TO THE MSKTUTIL_CORE INSTALL!      #
    #                                                #
    ##################################################
    
    [INFO] ... an active directory user account with the rights to join a computer object to the domain must be provided.
    [INFO] ... please enter your active directory username only (not username@domain or domain\username): 

Lot's of stuff flies by and it's really pretty if you have color in your terminal.  Otherwise it's just very, very verbose.  It also creates a logfile under /root/msktutil_core_install.log (or whatever you set the LOG_FILE variable to msktutil_core.conf).  
Sorry for the amount of noise but, in troubleshooting this script, more was better.  It's a lot easier to track down where something broke if you have a log to tell you.

The last bit here is that kinit **does not** accept passwords from a file.  This means that you will prompted for Active Directory user account password three times.  First, to configure the NFSV4 Service Principle Name (SPN).  
Second, to configure the HOST Service Principle Name (SPN).  And, third, to test the ability to query LDAP from the Linux server.  After each use, the Kerberos ticket is destroyed by calling ... :

    [root@server01]# kdestroy

... of course, this can be changed with a little tinkering in the script.  I don't mind typing my password three times, though, since the whole process takes less then one minute (including 15 seconds of wait time coded in to allow for stuff to get done in AD).  

**NOTE**:  The only way that I know to fully automate that step is to use Expect.  Which is to say, I don't know how to fully automate that part.  :)

**NOTE**:  If you truly cannot live with being prompted three times and demand to only be prompted once than make sure that you note where in the script you are being prompted.  If you try to set the password at the beginning it will fail because Kerberos is 
either not installed or not configured properly in /etc/krb5.conf.  Same thing for /etc/ldap.conf, /etc/ntp.conf, /etc/nsswitch.conf, etc., etc..  You must wait until the basic *things* are in place before you call kinit to request the Active Directory 
password for the user account that you specified when the script first launched.

In case you are wondering, it's **Step 29**.

issues
================

If you see **Step 35** [FAILED] when trying to start the service kstart_ldap ... :

    >>> STEP 35 - 20:40:24-EST - BEGIN START AND CONFIGURE K5START_LDAP SERVICE
    [PASS] ... the k5start_ldap service is stopped...starting the service.
    Starting k5start_ldap: k5start: error getting credentials: Client not found in Kerberos database
                                                               [FAILED]
    [INFO] ... the k5start_ldap service is configured for run-levels:
    k5start_ldap 0:off 1:off 2:on 3:on 4:on 5:on 6:off

... don't panic.  I'm not sure why this happens but it does from time to time.  If anyone can suggest a solution IO would be grateful.  Regardless, the solution is easy.  By that point in the script it's not really needed for anything other than the 
Active Directory LDAP query at **Step 37**.  That step will fail, too.  Just start the service and run the query manually ... :

    [root@server01]# service k5start_ldap status
    k5start is stopped
    [root@server01]# service k5start_ldap start
    Starting k5start_ldap:                                     [  OK  ]

... now, make sure that k5start_ldap did what it was supposed to do (get a HOST kerberos ticket) ... :

    [root@server01]# klist -cef /etc/.ldapcache 
    Ticket cache: FILE:/etc/.ldapcache
    Default principal: server01$@LUX.INTERNAL
    
    Valid starting     Expires            Service principal
    02/15/13 20:43:43  02/16/13 06:43:43  krbtgt/LUX.INTERNAL@LUX.INTERNAL
            renew until 02/22/13 20:43:43, Flags: FRIA
            Etype (skey, tkt): ArcFour with HMAC/md5, ArcFour with HMAC/md5 
    02/15/13 20:43:43  02/16/13 06:43:43  ldap/server01.lux.internal@LUX.INTERNAL
            renew until 02/22/13 20:43:43, Flags: FRAO
            Etype (skey, tkt): AES-256 CTS mode with 96-bit SHA-1 HMAC, AES-256 CTS mode with 96-bit SHA-1 HMAC

... now, try to query Active Directory LDAP again.  First, kinit with your Active Directory user account and provide the password when prompted... :

    [root@server01]# kinit badadmin_ldap
	Password for badadmin_ldap@LUX.INTERNAL:

... now, root has been granted a Kerberos ticket for badadmin_ldap ... :

    [root@server01]# klist -cef
    Ticket cache: FILE:/tmp/krb5cc_0
    Default principal: badadmin_ldap@LUX.INTERNAL
    
    Valid starting     Expires            Service principal
    02/15/13 20:51:44  02/16/13 06:51:44  krbtgt/LUX.INTERNAL@LUX.INTERNAL
            renew until 02/22/13 20:51:44, Flags: FRIA
            Etype (skey, tkt): ArcFour with HMAC/md5, ArcFour with HMAC/md5 
    
    
    Kerberos 4 ticket cache: /tmp/tkt0
    klist: You have no tickets cached

... now, root can query LDAP Active Directory using the credentials provided by badadmin_ldap ... :

    [root@server01]# /usr/bin/getent passwd luxuser01
    luxuser01:*:770000001:77001:LUX.INTERNAL LUXUSER01 TEST ACCOUNT:/home/luxuser01:/bin/bash
    [root@server01]# /usr/bin/ldapsearch cn=luxuser01 2>&1 | grep ^employeeID               
    employeeID: TEST_ACCT

... in this example, we have a test account called "luxuser01" setup in Active Directory.  As you see, both the getent and ldapsearch command worked.  Some notes worth mentioning ... :

* The getent command expects that the HOST has a Kerberos ticket.  In other words, when k5start_ldap failed to start earlier, the HOST could not see passwd beyond the local /etc/passwd file even though /etc/nsswitch is configured to search both locally and LDAP.
* The ldapsearch command, hwoever, **does** expect that user running has a Kerberos ticket that grants it the ability to query Active Directory.  In other words, unless root has a Kerberos ticket (by kinit'ng as an Active Directory user), then root will **not** be able to successfully run ldapsearcg even though the HOST has a valid Kerberos ticket.

checking your work
================

Verify the contents of /etc/krb5.keytab ... :

    [root@server01]# klist -ket
    Keytab name: FILE:/etc/krb5.keytab
    KVNO Timestamp         Principal
    ---- ----------------- --------------------------------------------------------    
       2 02/15/13 20:42:49 server01-nfs$@LUX.INTERNAL (ArcFour with HMAC/md5) 
       2 02/15/13 20:42:49 server01-nfs$@LUX.INTERNAL (AES-128 CTS mode with 96-bit SHA-1 HMAC) 
       2 02/15/13 20:42:49 server01-nfs$@LUX.INTERNAL (AES-256 CTS mode with 96-bit SHA-1 HMAC) 
       2 02/15/13 20:42:49 nfs/server01.lux.internal@LUX.INTERNAL (ArcFour with HMAC/md5) 
       2 02/15/13 20:42:49 nfs/server01.lux.internal@LUX.INTERNAL (AES-128 CTS mode with 96-bit SHA-1 HMAC) 
       2 02/15/13 20:42:49 nfs/server01.lux.internal@LUX.INTERNAL (AES-256 CTS mode with 96-bit SHA-1 HMAC) 
       2 02/15/13 20:43:14 server01$@LUX.INTERNAL (ArcFour with HMAC/md5) 
       2 02/15/13 20:43:14 server01$@LUX.INTERNAL (AES-128 CTS mode with 96-bit SHA-1 HMAC) 
       2 02/15/13 20:43:14 server01$@LUX.INTERNAL (AES-256 CTS mode with 96-bit SHA-1 HMAC) 
       2 02/15/13 20:43:14 host/server01.lux.internal@LUX.INTERNAL (ArcFour with HMAC/md5) 
       2 02/15/13 20:43:14 host/server01.lux.internal@LUX.INTERNAL (AES-128 CTS mode with 96-bit SHA-1 HMAC) 
       2 02/15/13 20:43:14 host/server01.lux.internal@LUX.INTERNAL (AES-256 CTS mode with 96-bit SHA-1 HMAC) 
       2 02/15/13 20:43:14 host/server01@LUX.INTERNAL (ArcFour with HMAC/md5) 
       2 02/15/13 20:43:14 host/server01@LUX.INTERNAL (AES-128 CTS mode with 96-bit SHA-1 HMAC) 
       2 02/15/13 20:43:14 host/server01@LUX.INTERNAL (AES-256 CTS mode with 96-bit SHA-1 HMAC)

Verify that sudo and /etc/sudoers work (you'll need to configure /etc/sudoers to you requirements, obviously) ... :

    [badadmin_ldap@server01]$ id
    uid=771234567(badadmin_ldap) gid=77001(UNIXGRP) groups=77001(UNIXGRP),77002(UNIXWHEEL)
    [badadmin_ldap@server01]$ sudo su -
    [root@server01]# cat /etc/sudoers | grep UNIXWHEEL
    %UNIXWHEEL      ALL=(ALL)       NOPASSWD: ALL

Confirm that require password change at first login work and that password change work in-general ... :

    Please enter login information for 192.168.0.50.
    Username: luxuser01
    Password: 
    Warning: password has expired.
    Last login: Fri Feb 15 12:40:28 2013 from 10.48.163.205
    *******************************************************************************
    *******************************************************************************
    **                                                                           **
    ** SECURITY NOTICE:                                                          **
    **                                                                           **
    ** Only authorized users may use this system for legitimate business         **
    ** purposes. There is no expectation of privacy in connection with your      **
    ** activities or the information handled, sent, or stored on this network.   **
    ** By accessing this system you accept that your actions on this network may **
    ** be monitored and/or recorded.  Information gathered may be used to pursue **
    ** any and all remedies available by law, including termination of           **
    ** employment or the providing of the evidence of such monitoring to law     **
    ** enforcement officials.                                                    **
    **                                                                           **
    *******************************************************************************
    *******************************************************************************
    WARNING: Your password has expired.
    You must change your password now and login again!
    Changing password for user luxuser01.
    Kerberos 5 Password: 
    New password: 
    BAD PASSWORD: is too similar to the old one
    New password: 
    BAD PASSWORD: it is based on a dictionary word
    New password: 
    Retype new password: 
    passwd: all authentication tokens updated successfully.

... and check logs ... :

    [root@server01]# tail -10 /var/log/secure | grep luxuser01
    Feb 15 21:12:38 server01 sshd[5792]: pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=192.168.0.100  user=luxuser01
    Feb 15 21:12:38 server01 sshd[5792]: pam_krb5[5792]: authentication succeeds for 'luxuser01' (luxuser01@LUX.INTERNAL)
    Feb 15 21:12:38 server01 sshd[5792]: pam_krb5[5792]: account checks fail for 'luxuser01': password has expired
    Feb 15 21:12:38 server01 sshd[5792]: Accepted password for luxuser01 from 192.168.0.100 port 22 ssh2
    Feb 15 21:12:38 server01 sshd[5792]: pam_unix(sshd:session): session opened for user luxuser01 by (uid=0)
    Feb 15 21:12:38 server01 passwd: pam_unix(passwd:chauthtok): user "luxuser01" does not exist in /etc/passwd
    Feb 15 21:13:10 server01 passwd: pam_unix(passwd:chauthtok): user "luxuser01" does not exist in /etc/passwd
    Feb 15 21:13:10 server01 passwd: pam_krb5[5795]: password changed for luxuser01@LUX.INTERNAL
    Feb 15 21:13:10 server01 sshd[5792]: pam_unix(sshd:session): session closed for user luxuser01

**NOTE**:  The issues with changing the password stem from the complexity rules RHEL 5 has by default.  There are ways to mitigate this but the solutions are less than stellar.  For example, want to eliminate the "BAD PASSWORD: it is based on a dictionary word" error? 
Well, per Red Hat,the solution is to zero out the dictionary file it uses.  That's fine until some schmuck creates a local service account and gives it a password of "password".  RHEL 5 password complexity requirements are actually more stringent than those 
found by default in Active Directory.  I'll see if I can find the Red Hat errata on how to fix them.

... verify that Kerberos works like it is supposed to work!  Once you have two servers set up in this manner, authenticate to one via SSH and then, from the server, SSH to the other.  You should not be prompted for a password.  
Let's see how it works ... :

... we're on **server01** and we check the hostname, our Kerberos ticket, and then ssh to **server02** ... :

    [badadmin_ldap@server01]$ hostname
    server01.lux.internal
    [badadmin_ldap@server01]$ klist -cef
    Ticket cache: FILE:/tmp/krb5cc_771234567_yJRWKu5812
    Default principal: badadmin_ldap@LUX.INTERNAL
    
    Valid starting     Expires            Service principal
    02/15/13 21:31:09  02/16/13 07:31:09  krbtgt/LUX.INTERNAL@LUX.INTERNAL
            renew until 02/22/13 21:31:09, Flags: FRIA
            Etype (skey, tkt): ArcFour with HMAC/md5, ArcFour with HMAC/md5 
        
        
    Kerberos 4 ticket cache: /tmp/tkt771234567
    klist: You have no tickets cached
    badadmin_ldap@server01.lux.internal:[/export/home/badadmin_ldap]$ ssh server02
	
... now we're on **server02** and we we not prompted for a password.  This is how Kerberos is supposed to work.  You already have a valid ticket from the Domain Controller.  When you SSH'd from **server01** to **server02**, GSSAPI on **server02** saw that 
and passed that back to the Domain Controller which then, rightfully, said, "badadmin_ldap already gave me his password earlier so here's a new ticket for him to use on **server02**".  We check the hostname to confirm that we're on **server02** (we are), 
we check to see that we have a valid Kerberos ticket on **server02** (we do), and then we end the SSH session (exit) ... :
	
    [badadmin_ldap@server02 ~]$ hostname
    server02.lux.internal
    [badadmin_ldap@server02 ~]$ klist -cef
    Ticket cache: FILE:/tmp/krb5cc_771234567_lUwvz23281
    Default principal: badadmin_ldap@LUX.INTERNAL
    
    Valid starting     Expires            Service principal
    02/15/13 21:37:10  02/16/13 07:31:09  krbtgt/LUX.INTERNAL@LUX.INTERNAL
            renew until 02/22/13 21:31:09, Flags: FfRA
            Etype (skey, tkt): ArcFour with HMAC/md5, ArcFour with HMAC/md5 
    
    
    Kerberos 4 ticket cache: /tmp/tkt771234567
    klist: You have no tickets cached
	[badadmin_ldap@server02 ~]$ exit
    logout
    
... but now we are back on **server01**.  What does our Kerberos ticket look like now?  It has a new entry showing that badadmin_ldap on **server01** has a valid Kerberos ticket for **server01** (the ticket itself) and and entry for **server02** ... :
	
    Connection to server02 closed.
    badadmin_ldap@vmaaron5.lux.internal:[/export/home/badadmin_ldap]$ klist -cef
    Ticket cache: FILE:/tmp/krb5cc_771234567_yJRWKu5812
    Default principal: badadmin_ldap@LUX.INTERNAL
    
    Valid starting     Expires            Service principal
    02/15/13 21:41:39  02/16/13 07:41:39  krbtgt/LUX.INTERNAL@LUX.INTERNAL
            renew until 02/22/13 21:41:39, Flags: FRIA
            Etype (skey, tkt): ArcFour with HMAC/md5, ArcFour with HMAC/md5 
    02/15/13 21:42:25  02/16/13 07:41:39  host/server02.lux.internal@LUX.INTERNAL
            renew until 02/22/13 21:41:39, Flags: FRAO
            Etype (skey, tkt): AES-256 CTS mode with 96-bit SHA-1 HMAC, AES-256 CTS mode with 96-bit SHA-1 HMAC 
    
    
    Kerberos 4 ticket cache: /tmp/tkt775002560
    klist: You have no tickets cached

... that's what Kerberos is supposed to do for you.  Let's hop back over to **server02** and see what the logs say about it ... :

    [badadmin_ldap@server02]$ sudo tail -25 /var/log/secure | grep badadmin_ldap
    Feb 15 21:42:25 server02 sshd[23335]: Authorized to badadmin_ldap, krb5 principal badadmin_ldap@LUX.INTERNAL (krb5_kuserok)
    Feb 15 21:42:25 server02 sshd[23335]: Accepted gssapi-with-mic for badadmin_ldap from 192.168.0.50 port 36885 ssh2
    Feb 15 21:42:25 server02 sshd[23335]: pam_unix(sshd:session): session opened for user badadmin_ldap by (uid=0)
    Feb 15 21:42:31 server02 sshd[23335]: pam_unix(sshd:session): session closed for user badadmin_ldap

... that bit about [krb5_kuserok](http://web.mit.edu/kerberos/krb5-devel/doc/appdev/refs/api/krb5_kuserok.html).  Per MIT and Heimdal, to be sure, krb5_kuserok is basically saying badadmin_ldap already has a valid principle and can, therefore, login.  
	
changes to your local user account
================

You will want to add this to your local account' .bash_profile.  This is what allows you to be prompted by kinit when you need to enter your Active Directory password.  Otherwise, you'll get a Kerberos error and need to *know* to type "kinit badadmin_ldap" ... :

    # Ask k5start to check for a happy (-H) Kerberos ticket
    export PROMPT_COMMAND="k5start -H 360"

starting over
================

If you need to run the script again on the same server, I usually do the following ... :

* delete computer object for the HOST and the NFSv4 SPN (by script defaults, under LUX.INTERNAL > LUX > HOSTS and LUX.INTERNAL > LUX > HOSTS > SERVICES).
* stop the k5start_ldap service (# service k5start_ldap stop)
* delete the HOST Kerberos cache (# rm /etc/.ldapcache)
* delete the HOST Kerberos keytab file (# rm /etc/krb5.keytab)

... once complete, you should be able to run the script again wihtout issue.
	
conclusion
================
What haven't I covered here?  AutoFS.  I'm still working on getting NFSv4 sorted out properly *and* getting NFSv4 AutoFS automount maps to work when presented from Active Directory.  NFSv3 and NFSv4 without Kerberos work fine; I just haven't 
had time to play with NFSv4 with Kerberos.  The point in telling you this?  You can probably get rid of the NFSv4 stuff from the script since I've no idea when I'll get it functional.

Again, please let me know how I can make this better.  As you can tell, I'm not the world' most accomplished wielder of bash.  Or NFSv4 with Kerberos :)