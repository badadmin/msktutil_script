#!/bin/bash

#  msktutil_core.sh:  a script to configure RHEL 5 servers to authenticate against
#+ ldap and kerberos using active directory as the ldap and kerberos provider.
#  author:  aaron wyllie <aaron.t.wyllie@gmail.com>
#  created:  october 1, 2012
#  last updated:  february 15, 2013
#  version:  0.06

### DEFINE FUNCTIONS ###

#  usage function:
usage (){
    echo "Usage: $0 hostname"
    exit 1
}

#  create log files function:
logFiles (){
    touch $LOG_FILE
    touch $ERR_FILE
    echo "msktutil_core log file created: "$DATE_01 >> $LOG_FILE
    echo "msktutil_core error file created: "$DATE_01 >> $ERR_FILE
    echo "<<< BEGIN MSKTUTIL_CORE INSTALL >>>" | tee -a $LOG_FILE
    echo "[$INFO] ... INSTALL START TIME: $DATE_02" | tee -a $LOG_FILE
    echo "" | tee -a  $LOG_FILE
}

#  prompt for username function:
adUser (){
    echo "[$INFO] ... an active directory user account with the rights to join a computer object to the domain must be provided." | tee -a $LOG_FILE
    echo "[$INFO] ... please enter your active directory username only (not username@domain or domain\username): " | tee -a $LOG_FILE
    read ADMIN_USERNAME
    echo "[$INFO] ... all actions performed by this script against against directory will be logged as: $ADMIN_USERNAME" | tee -a $LOG_FILE
    echo "[$INFO] ... you will be prompted one or more times during this script to provide the active directory password for this account." | tee -a $LOG_FILE
    echo "[$INFO] ... this is because a kerberos ticket from active directory is required to perform changes to active directory." | tee -a $LOG_FILE
    echo "[$INFO] ... the kerberos ticket is immediately destroyed once it is no longer required." | tee -a $LOG_FILE
    echo "[$INFO] ... this is a feature, not an annoyance as kerberos connectivity to active directory should be configured by the time you are prompted." | tee -a $LOG_FILE
    echo "[$INFO] ... if the kerberos ticket requests fails then server was not properly configured by this script and you should consult the $LOG_FILE file for more information." | tee -a $LOG_FILE
	echo "" | tee -a $LOG_FILE
}

#  check to see if this is a linux server function:
isLinux (){
    echo ">>> STEP 01 - $DATE_02 - BEGIN PLATFORM CHECK" | tee -a $LOG_FILE
    if [ "$PLATFORM" != "Linux" ]; then
        echo "[$FAIL] ... this server is not running Linux." | tee -a $LOG_FILE
        echo "[$FAIL] ... this script will exit now." | tee -a $LOG_FILE
        exit 0
    else
        echo "PLATFORM: " `uname` | tee -a $LOG_FILE
        echo "[$PASS] ... this server is running Linux." | tee -a $LOG_FILE
    fi
    echo "" | tee -a  $LOG_FILE
}

#  check which version of RHEL the server is running function:
rhelVersion (){
    echo ">>> STEP 02 - $DATE_02 - BEGIN VERIFY OS VERSION" | tee -a $LOG_FILE
    if [ ! -e "$OS_VERSION" ];
    then
        echo "[$FAIL] ... cannot find the $OS_VERSION directory.  unable to continue." | tee -a $LOG_FILE
        echo "[$FAIL] ... are you sure this is a RHEL or RHEL-clone server?" | tee -a $LOG_FILE
        exit 0
    elif [ "$(grep 5 $OS_VERSION | wc -l)" = "1" ];
    then
        OS=RHEL5
        echo "VERSION: " `/bin/cat /etc/redhat-release` | tee -a $LOG_FILE
        echo "[$INFO] ... this is a $OS or an $OS-clone server." | tee -a $LOG_FILE
    elif [ "$(grep 6 $OS_VERSION | wc -l)" = "1" ];
    then
        OS=RHEL6
        echo "VERSION: " `/bin/cat /etc/redhat-release` | tee -a $LOG_FILE
        echo "[$INFO] ... this is a $OS or an $OS-clone server." | tee -a $LOG_FILE
    fi
    echo "" | tee -a  $LOG_FILE
}

#  check what architecture the server is using function:
whatArch (){
    echo ">>> STEP 03 - $DATE_02 - BEGIN VERIFY ARCHITECTURE" | tee -a $LOG_FILE
    if [ "$ARCH_VERSION" != "i386" ] && [ "$ARCH_VERSION" != "x86_64" ];
    then
        echo "[$FAIL] ... cannot determine the server architecture.  unable to continue." | tee -a $LOG_FILE
        echo "[$FAIL] ... are you sure this is an i386 or x86_64 architecture server?" | tee -a $LOG_FILE
    exit 0
    elif [ "$ARCH_VERSION" = "i386" ];
    then
        ARCH=I386
        echo "ARCHITECTURE: " `/bin/uname -p` | tee -a $LOG_FILE
        echo "[$INFO]...this server is using i386 architecture." | tee -a $LOG_FILE
    elif [ "$ARCH_VERSION" = "x86_64" ];
    then
        ARCH=X86_64
        echo "ARCHITECTURE: " `/bin/uname -p` | tee -a $LOG_FILE
        echo "[$INFO] ... this server is using x86_64 architecture." | tee -a $LOG_FILE
    fi
    echo "" | tee -a  $LOG_FILE
}

#  first file backup function:
firstBackup (){
    echo ">>> STEP 04 - $DATE_02 - BEGIN INITIAL FILE BACKUPS" | tee -a $LOG_FILE
    if [ ! -d $BACKUP_DIR_01 ]; then
        mkdir -p $BACKUP_DIR_01
    fi

    filelist=(
    $MOTD_FILE \
    $HOSTS_FILE \
    $KRB5_FILE \
    $KRB5_KEYTAB_FILE \
    $NSCD_FILE \
    $NSSWITCH_FILE \
    $LDAP_FILE \
    $OPENLDAP_FILE \
    $IDMAPD_FILE \
    $AUTOFS_LDAP_AUTH_FILE \
    $PAM_FILE \
    $SSH_FILE \
    $SSHD_FILE \
    $HOSTNAME_FILE \
    $NFS_FILE \
    $AUTOFS_FILE \
    $SMB_FILE \
    $AUTHCONFIG_FILE \
    $NTP_FILE \
    $RESOLV_FILE \
    $SYSCONFIG_NFS_FILE \
    $SYSCONFIG_AUTOFS_FILE \
    $K5START_LDAP_FILE \
    $K5START_NFSV4_FILE \
    )

    backup_filelist=(
    $MOTD_BACKUP_FILE \
    $HOSTS_BACKUP_FILE \
    $KRB5_BACKUP_FILE \
    $KRB5_KEYTAB_BACKUP_FILE \
    $NSCD_BACKUP_FILE \
    $NSSWITCH_BACKUP_FILE \
    $LDAP_BACKUP_FILE \
    $OPENLDAP_BACKUP_FILE \
    $IDMAPD_BACKP_FILE \
    $AUTOFS_LDAP_AUTH_BACKUP_FILE \
    $PAM_BACKUP_FILE \
    $SSH_BACUP_FILE \
    $SSHD_BACKUP_FILE \
    $HOSTNAME_BACKUP_FILE \
    $NFS_BACKUP_FILE \
    $AUTOFS_BACKUP_FILE \
    $SMB_BACKUP_FILE \
    $AUTHCONFIG_BACKUP_FILE \
    $NTP_BACKUP_FILE \
    $RESOLV_BACKUP_FILE \
    $SYSCONFIG_NFS_BACKUP_FILE \
    $SYSCONFIG_AUTOFS_BACKUP_FILE \
    $K5START_LDAP_BACKUP_FILE \
    $K5START_NFSV4_BACKUP_FILE \
    )
    
    for file in ${filelist[*]};
    do
        if [ -e $file ];
        then
            echo "[$PASS] ... the $file file was found." | tee -a $LOG_FILE
        else
            echo "[$WARN] ... unable to find the $file file.  it does not exist in the directory specified." | tee -a $LOG_FILE
        fi
    done

    for file in ${filelist[*]};
    do
        if [ -e $file ];
        then
            cp $file $BACKUP_DIR_01/$(echo $file|awk 'BEGIN{FS="/"}{gsub("/","_")}{print substr($1,2); }').bak # removes the leading '_'.
        fi
    done
    
    for file in ${backup_filelist[*]};
    do
        if [ -e $BACKUP_DIR_01/$file ];
        then
            echo "[$PASS] ... the $file backup file was successfully created in $BACKUP_DIR_01." | tee -a $LOG_FILE
        else
            echo "[$WARN] ... unable to create the $file backup file.  the source file does not exist." | tee -a $LOG_FILE
        fi
    done
    echo "" | tee -a  $LOG_FILE
}

#  import epel repository key function:
epelKey (){
    echo ">>> STEP 05 - $DATE_02 - BEGIN UPLOAD & INSTALL EPEL REPOSITORY GPG KEY" | tee -a $LOG_FILE
    if [ -e $EPEL_KEY ];
    then
        declare KEY_CHECK_01=$(gpg --quiet --with-fingerprint $EPEL_KEY)
        echo "[$INFO] ... looks like we already have a key in $EPEL_KEY." | tee -a $LOG_FILE
        echo "[$INFO] ... verifying integrity of existing EPEL Repository key." | tee -a $LOG_FILE
        echo "[$INFO] ... key fingerprint should match: B940 BE07 7D71 0A28 7D7F  2DD1 119C C036 2175 21F6" | tee -a $LOG_FILE
        echo "[$INFO] ... here is the key we currently have installed:" | tee -a $LOG_FILE
        echo  "$KEY_CHECK_01" | tee -a $LOG_FILE
            if [ $(gpg --quiet --with-fingerprint $EPEL_KEY | grep "$EPEL_RHEL5_KEY_FINGERPRINT" | wc -l) = "1" ];
            then
                echo "[$PASS] ... the existing EPEL repository fingerprint matches: B940 BE07 7D71 0A28 7D7F  2DD1 119C C036 2175 21F6" | tee -a $LOG_FILE
            else
                echo "[$FAIL] ... the existing EPEL repository fingerprint does not match: B940 BE07 7D71 0A28 7D7F  2DD1 119C C036 2175 21F6" | tee -a $LOG_FILE
                echo "[$FAIL] ... we need to remove this key and install the correct one."
                rm -f $EPEL_KEY
            fi
    else
        cp ${SOURCEDIR}/RPM/RHEL_5/EPEL_REPO_KEY/217521F6.txt /tmp/RPM-GPG-KEY-EPEL.txt
        mv /tmp/RPM-GPG-KEY-EPEL.txt $EPEL_KEY
        chmod 644 $EPEL_KEY
        chown root.root $EPEL_KEY
        rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL
        declare KEY_CHECK_02=$(gpg --quiet --with-fingerprint $EPEL_KEY)
        echo "[$WARN] ... looks like we don't have an EPEL RHEL 5 repository key installed so we're going to install one." | tee -a $LOG_FILE
        echo "[$INFO] ... verifying integrity of EPEL repository key." | tee -a $LOG_FILE
        echo "[$INFO] ... key fingerprint should match: B940 BE07 7D71 0A28 7D7F  2DD1 119C C036 2175 21F6" | tee -a $LOG_FILE
        echo "[$INFO] ... here is the key we imported:" | tee -a $LOG_FILE
        echo  "$KEY_CHECK_02" | tee -a $LOG_FILE
            if [ $(gpg --quiet --with-fingerprint $EPEL_KEY | grep "$EPEL_RHEL5_KEY_FINGERPRINT" | wc -l) = "1" ];
                then
                    echo "[$PASS] ... EPEL repository fingerprint matches:  B940 BE07 7D71 0A28 7D7F  2DD1 119C C036 2175 21F6" | tee -a $LOG_FILE
                else
                    echo "[$FAIL] ... EPEL repository fingerprints do not match." | tee -a $LOG_FILE
                    echo "[$FAIL] ... a problem exists with the EPEL repository key we installed."  | tee -a $LOG_FILE
                    echo "[$FAIL] ... this script will exit now." | tee -a $LOG_FILE
                    exit 0
            fi
    fi
    echo "" | tee -a $LOG_FILE
}

#  upload k5start_ldap init script function:
uploadK5startLDAP (){
    echo ">>> STEP 06 - $DATE_02 - BEGIN UPLOAD K5START_LDAP" | tee -a $LOG_FILE
    if [ -e $K5START_LDAP_FILE ];
    then
        echo "[$PASS] ... looks like $K5START_LDAP_FILE already exists!" | tee -a $LOG_FILE
    else
        echo "[$WARN] ... the $K5START_LDAP_FILE file does not exist." | tee -a $LOG_FILE
        cp ${SOURCEDIR}/OS/RHEL_5_SCRIPTS/k5start_ldap $K5START_LDAP_FILE
        chmod 755 $K5START_LDAP_FILE
        chown root.root $K5START_LDAP_FILE
        echo "[$PASS] ... the k5start_ldap INIT script has been uploaded to $K5START_LDAP_FILE." | tee -a $LOG_FILE
	fi
    echo "" | tee -a  $LOG_FILE
}

#  upload k5start_nfsv4 init script function: DOES NOT WORK - DO NOT USE
uploadK5startNFSv4 (){
    echo ">>> STEP 07 - $DATE_02 - BEGIN UPLOAD K5START_NFSV4" | tee -a $LOG_FILE
    if [ -e $K5START_NFSV4_FILE ];
    then
        echo "[$PASS] ... looks like $K5START_NFSV4_FILE already exists!" | tee -a $LOG_FILE
    else
        echo "[$WARN] ... the $K5START_NFSV4_FILE file does not exist." | tee -a $LOG_FILE
        cp ${SOURCEDIR}/OS/RHEL_5_SCRIPTS/k5start_nfsv4 $K5START_NFSV4_FILE
        chmod 755 $K5START_NFSV4_FILE
        chown root.root $K5START_NFSV4_FILE
        echo "[$PASS] ... the k5start_nfsv4 INIT script has been uploaded to $K5START_NFSV4_FILE." | tee -a $LOG_FILE
	fi
    echo "" | tee -a  $LOG_FILE
}

#  upload krb5-ticket-renew.sh script:
uploadKrb5TicketRenew (){
    echo ">>> STEP 08 - $DATE_02 - BEGIN UPLOAD KRB5-TICKET-RENEW.SH"  | tee -a $LOG_FILE
    if [ -e $K5START_TICKET_RENEW_FILE ];
    then
        echo "[$PASS] ... looks like $K5START_TICKET_RENEW_FILE already exists!" | tee -a $LOG_FILE
    else
        echo "[$WARN] ... the $K5START_TICKET_RENEW_FILE file does not exist." | tee -a $LOG_FILE
        cp ${SOURCEDIR}/OS/RHEL_5_SCRIPTS/krb5-ticket-renew.sh $K5START_TICKET_RENEW_FILE
        chmod 750 $K5START_TICKET_RENEW_FILE
        chown root.root $K5START_TICKET_RENEW_FILE
        echo "[$PASS] ... The krb5-ticket-renew.sh script has been uploaded to $K5START_TICKET_RENEW_FILE." | tee -a $LOG_FILE
	fi
    echo "" | tee -a  $LOG_FILE
}

#  upload the krb5-ticket-renew.conf file:
uploadKrb5TicketRenewConf (){
    echo ">>> STEP 09 - $DATE_02 - BEGIN UPLOAD KRB5-TICKET-RENEW.CONF" | tee -a $LOG_FILE
    if [ -e $K5START_TICKET_RENEW_CONF_FILE ];
    then
        echo "[$PASS] ... looks like $K5START_TICKET_RENEW_CONF_FILE already exists!" | tee -a $LOG_FILE
    else
        echo "[$WARN] ... the $K5START_TICKET_RENEW_CONF_FILE file does not exist." | tee -a $LOG_FILE
        cp ${SOURCEDIR}/OS/RHEL_5_SCRIPTS/krb5-ticket-renew.conf $K5START_TICKET_RENEW_CONF_FILE
        chmod 600 $K5START_TICKET_RENEW_CONF_FILE
        chown root.root $K5START_TICKET_RENEW_CONF_FILE
        echo "[$PASS] ... the krb5-ticket-renew.conf file has been uploaded to $K5START_TICKET_RENEW_CONF_FILE." | tee -a $LOG_FILE    
	fi
    echo "" | tee -a  $LOG_FILE
}

#  install core dependencies function:
coreRPMInstall (){
    echo ">>> STEP 10 - $DATE_02 - BEGIN INSTALL CORE DEPENDENCIES" | tee -a $LOG_FILE
    yum install make gcc-c++ cyrus-sasl-gssapi cyrus-sasl-md5 cyrus-sasl-devel openldap-devel krb5-devel -y
    echo "[$PASS] ... core RPM dependendencies installed." | tee -a $LOG_FILE
    echo "" | tee -a  $LOG_FILE
}

#  install kstart-3.16-1.el5.1.x86_64.rpm function:
installKstart (){ 
    echo ">>> STEP 11 - $DATE_02 - BEGIN INSTALL KSTART" | tee -a $LOG_FILE
    if [ $(yum info kstart | grep ^Repo | grep installed | wc -l) != "1" ];
    then
        yum install ${SOURCEDIR}/RPM/RHEL_5/x86_64/kstart-4.1-2.el5.1.x86_64.rpm -y
        echo "[$PASS] ... the kstart package has been installed." | tee -a $LOG_FILE
    else
        echo "[$INFO] ... the kstart package is already installed." | tee -a $LOG_FILE
    fi
    echo "" | tee -a  $LOG_FILE
}

# install msktutil-0.4.2-1.el5.x86_64.rpm function:
installMsktutil (){
    echo ">>> STEP 12 - $DATE_02 - BEGIN INSTALL MSKTUTIL" | tee -a $LOG_FILE
    if [ $(yum info msktutil | grep ^Repo | grep installed | wc -l) != "1" ];
    then
        yum install ${SOURCEDIR}/RPM/RHEL_5/x86_64/msktutil-0.4.2-1.el5.x86_64.rpm -y
        echo "[$PASS] ... the msktutil package has been installed." | tee -a $LOG_FILE
    elif [ $(yum info msktutil | grep ^Version | grep 0.4.2 | wc -l) != "1" ];
    then
        echo "[$INFO] ... the currently installed version of msktutil is out of date and will be removed." | tee -a $LOG_FILE
        yum remove msktutil -y
        echo "[$INFO] ... the currently installed version of msktutil has been removed." | tee -a $LOG_FILE
        echo "[$INFO] ... installing the most recently available version of msktutil." | tee -a $LOG_FILE
        yum install ${SOURCEDIR}/RPM/RHEL_5/x86_64/msktutil-0.4.2-1.el5.x86_64.rpm -y
        echo "[$PASS] ... the msktutil package has been installed." | tee -a $LOG_FILE
    else    
        echo "[$INFO] ... the msktutil package is already installed." | tee -a $LOG_FILE
    fi
    echo "" | tee -a  $LOG_FILE
}

#  check for and install krb5-workstation RPM function:
installKrb5Workstation (){
    echo ">>> STEP 13 - $DATE_02 - BEGIN INSTALL KRB5-WORKSTATION" | tee -a $LOG_FILE
    if [ $(yum info krb5-workstation | grep ^Repo | grep installed | wc -l) != "1" ];
    then
        yum install krb5-workstation -y
        echo "[$PASS] ... the krb5-workstation package has been installed." | tee -a $LOG_FILE
    else
        echo "[$INFO] ... the krb5-workstation package is already installed." | tee -a $LOG_FILE
    fi
    echo "" | tee -a  $LOG_FILE
}

#  check for and install nss_ldap RPM function:
installNssLdap (){
    echo ">>> STEP 14 - BEGIN INSTALL NSS_LDAP" | tee -a $LOG_FILE
    if [ $(yum info nss_ldap | grep ^Repo | grep installed | wc -l) != "2" ];
    then
        yum install nss_ldap -y
        echo "[$PASS] ... the nss_ldap package has been installed." | tee -a $LOG_FILE
    else
        echo "[$INFO] ... the nss_ldap package is already installed." | tee -a $LOG_FILE
    fi
    echo "" | tee -a  $LOG_FILE
}

#  check for and install openldap RPM function:
installOpenLdap (){
    echo ">>> STEP 15 - $DATE_02 - BEGIN INSTALL OPENLDAP" | tee -a $LOG_FILE
    if [ $(yum info openldap | grep ^Repo | grep installed | wc -l) != "2" ];
    then
        yum install openldap -y
        echo "[$PASS] ... the openldap package has been installed." | tee -a $LOG_FILE
    else
        echo "[$INFO] ... the openldap package is already installed." | tee -a $LOG_FILE
    fi
    echo "" | tee -a  $LOG_FILE
}

#  check for and install the openldap-clients RPM function:

installOpenLdapClients (){
    echo ">>> STEP 16 - $STEP_02 - BEGIN INSTALL OPENLDAP-CLIENTS" | tee -a $LOG_FILE
    if [ $(yum info openldap-clients | grep ^Repo | grep installed | wc -l) != "1" ];
    then
        yum install openldap-clients -y
        echo "[$PASS] ... the openldap-clients package has been installed." | tee -a $LOG_FILE
    else
        echo "[$INFO] ... the openldap-clients package is already installed." | tee -a $LOG_FILE
    fi
    echo "" | tee -a  $LOG_FILE
}

#  check for the samba winbindd service, stop it, and uninstall it
removeWinbind (){
    #  ...stop service
    echo ">>> STEP 17 - $DATE_02 - BEGIN SAMBA WINDBIND REMOVAL" | tee -a $LOG_FILE
    OUTPUT=$(ps aux | grep -v grep | grep -v $0 | grep $WINBINDD_SERVICE)
    if [ "${#OUTPUT}" -gt 0 ];
    then
        echo "[$PASS] ... the $WINBINND_SERVICE_NAME service is running...stopping service." | tee -a $LOG_FILE && service $WINBINND_SERVICE_NAME stop
    else
        echo "[$PASS] ... the $WINBINDD_SERVICE_NAME service is not running." | tee -a $LOG_FILE
    fi
    #  ...set run levels to off
    echo "[$PASS] ... turning winbind service off..." | tee -a $LOG_FILE
    chkconfig winbind off
    echo "[$PASS] ... confirming winbind service status..." | tee -a $LOG_FILE
    echo `chkconfig winbind --list` | tee -a $LOG_FILE
    # ...remove samba3x packages
    echo "[$PASS] ... uninstalling the samba3x, samba3x-common, and samba3x-winbind packages now." | tee -a $LOG_FILE
    if [ $(yum info samba3x* | grep ^Repo | grep installed | wc -l) != "0" ];
    then
        yum remove samba3x* -y
        echo "[$PASS] ... the samba3x* packages have been uninstalled." | tee -a $LOG_FILE
    else
        echo "[$INFO] ... the are no Samba 3 packages currently installed." | tee -a $LOG_FILE
    fi
    echo "" | tee -a  $LOG_FILE
}

#  Update the /etc/hosts file function:
updateHosts (){
    echo ">>> STEP 18 - $DATE_02 - BEGIN CONFIGURE /ETC/HOSTS" | tee -a $LOG_FILE
	#  ...if you have additonal entries, add them below this initial one as follows:
	#	if [ $(grep ^$DC_02_IP $HOSTS_FILE | wc -l) != "1" ];
	#	then
	#		echo "[$FAIL]...No entry for $DC_02_IP in found $HOSTS_FILE." | tee -a $LOG_FILE
	#		echo "$DC_02_IP   $DC_02_FQDN     $DC_02_HOSTNAME       $DESCRIPTION" >> $HOSTS_FILE
	#		echo "[$PASS]...Added the following entry to $HOSTS_FILE:" | tee -a $LOG_FILE
	#		echo `grep ^$DC_02_IP $HOSTS_FILE` | tee -a $LOG_FILE
	#	else
	#		echo "[$WARN]...Entry for $DC_02_IP already present in $HOSTS_FILE!" | tee -a $LOG_FILE
	#		echo `grep ^$DC_02_IP $HOSTS_FILE` | tee -a $LOG_FILE
	#	fi
    if [ $(grep ^$DC_01_IP $HOSTS_FILE | wc -l) != "1" ];
    then
        echo "[$FAIL] ... no entry for $DC_01_IP found in $HOSTS_FILE." | tee -a $LOG_FILE
        echo "$DC_01_IP   $DC_01_FQDN     $DC_01_HOSTNAME       $DESCRIPTION" >> $HOSTS_FILE
        echo "[$PASS] ... added the following entry to $HOSTS_FILE:" | tee -a $LOG_FILE
        echo `grep ^$DC_01_IP $HOSTS_FILE` | tee -a $LOG_FILE
    else
        echo "[$INFO] ... entry for $DC_01_IP already present in $HOSTS_FILE." | tee -a $LOG_FILE
        echo `grep ^$DC_01_IP $HOSTS_FILE` | tee -a $LOG_FILE
    fi
    if [ $(grep ^$DC_02_IP $HOSTS_FILE | wc -l) != "1" ];
    then
        echo "[$FAIL] ... no entry for $DC_01_IP found in $HOSTS_FILE." | tee -a $LOG_FILE
        echo "$DC_02_IP   $DC_02_FQDN     $DC_02_HOSTNAME       $DESCRIPTION" >> $HOSTS_FILE
        echo "[$PASS] ... added the following entry to $HOSTS_FILE:" | tee -a $LOG_FILE
        echo `grep ^$DC_02_IP $HOSTS_FILE` | tee -a $LOG_FILE
    else
        echo "[$INFO] ... Entry for $DC_02_IP already present in $HOSTS_FILE." | tee -a $LOG_FILE
        echo `grep ^$DC_02_IP $HOSTS_FILE` | tee -a $LOG_FILE
    fi
    echo "" | tee -a  $LOG_FILE
}

#  create the /etc/resolv.conf file function:
configResolv (){
    echo ">>> STEP 19 - $DATE_02 - BEGIN CONFIGURE /ETC/RESOLV.CONF" | tee -a $LOG_FILE
    #  ...empty the current /etc/resolv.conf file
    > $RESOLV_FILE
    #  ...create the new /etc/resolv.conf file
    cat <<EOF > $RESOLV_FILE
search $NS_DOMAIN_01
nameserver $NS_01_IP
nameserver $NS_02_IP
EOF
    echo "[$INFO] ... the /etc/resolv.conf file has been updated." | tee -a $LOG_FILE
    echo "" | tee -a  $LOG_FILE
}

#  create the /etc/ntp.conf file and configure ntpd function:
configNtp (){
    echo ">>> STEP 20 - $DATE_02 - BEGIN CONFIGURE /ETC/NTP.CONF" | tee -a $LOG_FILE
    OUTPUT_01=$(ps aux | grep -v grep | grep $NTPD_SERVICE)
    if [ "${#OUTPUT_01}" -gt 0 ];
    then
        echo "[$PASS] ... the $NTPD_SERVICE service is running...stopping service." | tee -a $LOG_FILE && service $NTPD_SERVICE stop
    else
        echo "[$PASS] ... the $NTPD_SERVICE service is not running." | tee -a $LOG_FILE
    fi
    #  ...empty the current /etc/ntp.conf file
    > $NTP_FILE
    #  ...add the correct /etc/ntp.conf parameters
    cat <<EOF > $NTP_FILE
restrict 127.0.0.1 
restrict -6 ::1
server $DC_01_IP
server $DC_02_IP
driftfile $NTP_DRIFT_DIRECTORY
server 127.127.1.0
fudge  127.127.1.0 stratum 10
EOF
    #  ...check the availability of the NTP time sync sources
	#  ...if you have additonal domain controllers to configure ntpd against
	#+ ...add them below the first two lines below as follow:
	#	echo "[$INFO]...Perform initial time sync of NTP for time sync source $DC_02_IP..." | tee -a $LOG_FILE
	#	echo `ntpdate $DC_02_IP` | tee -a $LOG_FILE
    echo "[$INFO] ... perform initial time sync of NTP for time sync source $DC_01_IP..." | tee -a $LOG_FILE
    echo `ntpdate $DC_01_IP` | tee -a $LOG_FILE
    echo "[$INFO] ... perform initial time sync of NTP for time sync source $DC_02_IP..." | tee -a $LOG_FILE
    echo `ntpdate $DC_02_IP` | tee -a $LOG_FILE
    #  ...start the ntpd service
    OUTPUT_02=$(ps aux | grep -v grep | grep $NTPD_SERVICE)
    if [ "${#OUTPUT_02}" -lt 1 ];
    then
        echo "[$PASS] ... the $NTPD_SERVICE service is stopped...starting the service." | tee -a $LOG_FILE && service $NTPD_SERVICE start
    else
        echo "[$PASS] ... the $NTPD_SERVICE service is already running." | tee -a $LOG_FILE
    fi
    # ...query the NTP peer time sources
    declare NTP_TEST=$(ntpq -p)
    echo "$NTP_TEST" | tee -a $LOG_FILE
    echo "[$INFO] ... the $NTP_FILE file and $NTPD_SERVICE has been updated and configured." | tee -a $LOG_FILE
    echo "" | tee -a  $LOG_FILE
}

#  configure the HOSTNAME value in /etc/sysconfig/network function:
configNetwork (){
    echo ">>> STEP 21 - $DATE_02 - BEGIN CONFIGURE SYSTEM HOSTNAME" | tee -a $LOG_FILE
    #   ...clear out the current /etc/sysconfig/network file
    > $HOSTNAME_FILE
    #  ...create new /etc/sysconfig/network file
    cat <<EOF > $HOSTNAME_FILE
NETWORKING=yes
NETWORKING_IPV6=no
HOSTNAME=$HOSTFQDN
EOF
    #  ...verify hostname values
    echo "[$INFO] ... verify system FQDN: "`hostname -f` | tee -a $LOG_FILE
    echo "[$INFO] ... verify system hostname: "`hostname -s` | tee -a $LOG_FILE
    echo "[$INFO] ... verify system domain: "`hostname -d` | tee -a $LOG_FILE
	echo "" | tee -a $LOG_FILE
}

#  initial authconfig function:
initAuthConfig (){
    echo ">>> STEP 22 - $DATE_02 - BEGIN CONFIGURE /ETC/SYSCONFIG/AUTHCONFIG" | tee -a $LOG_FILE
    /usr/sbin/authconfig --enablekrb5 --krb5realm=$KRB5_REALM_01 --enablekrb5kdcdns --disableldapauth --disablewinbindauth --disablewinbind --enableldap --ldapserver $DC_01_FQDN --ldapbasedn dc=$DN_01_BASE,dc=$DN_02_BASE --enablelocauthorize --disablesmbauth --update
	echo ""
    echo "[$INFO] ... the contents of /etc/sysconfig/authconfig:" | tee -a $LOG_FILE
    cat /etc/sysconfig/authconfig | tee -a $LOG_FILE
    echo ""
    echo "[$INFO] ... initial system configuration via authconfig is complete." | tee -a $LOG_FILE
    echo "" | tee -a  $LOG_FILE
}

#  create new /etc/nscd.conf file functions:
createNscdConf (){
    echo ">>> STEP 23 - $DATE_02 - BEGIN CONFIGURE /ETC/NSCD.CONF" | tee -a $LOG_FILE
    #  ... clear out the current /etc/nscd.conf file
    > $NSCD_FILE
    # ... create the new /etc/nscd.conf file
    cat <<EOF > $NSCD_FILE
### THIS FILE CREATED BY THE DEVCENTER MAGICLAMP PROJECT ON $DATE ###
#
# /etc/nscd.conf
#
# An example Name Service Cache config file.  This file is needed by nscd.
#
# Legal entries are:
#
#       logfile                 <file>
#       debug-level             <level>
#       threads                 <initial #threads to use>
#       max-threads             <maximum #threads to use>
#       server-user             <user to run server as instead of root>
#               server-user is ignored if nscd is started with -S parameters
#       stat-user               <user who is allowed to request statistics>
#       reload-count            unlimited|<number>
#       paranoia                <yes|no>
#       restart-interval        <time in seconds>
#
#       enable-cache            <service> <yes|no>
#       positive-time-to-live   <service> <time in seconds>
#       negative-time-to-live   <service> <time in seconds>
#       suggested-size          <service> <prime number>
#       check-files             <service> <yes|no>
#       persistent              <service> <yes|no>
#       shared                  <service> <yes|no>
#       max-db-size             <service> <number bytes>
#       auto-propagate          <service> <yes|no>
#
# Currently supported cache names (services): passwd, group, hosts
#


$NSCD_LOGFILE
$NSCD_THREADS
$NSCD_MAX_THREADS
$NSCD_SERVER_USER
$NSCD_STAT_USER
$NSCD_DEBUG_LEVEL
$NSCD_RELOAD_COUNT
$NSCD_PARANOIA
$NSCD_RESTART_INTERVAL

$NSCD_PASSWD_ENABLE_CACHE
$NSCD_PASSWD_POSITIVE_TTL
$NSCD_PASSWD_NEGATIVE_TTL
$NSCD_PASSWD_SUGGESTED_SIZE
$NSCD_PASSWD_CHECK_FILES
$NSCD_PASSWD_PERSISTENT
$NSCD_PASSWD_SHARED
$NSCD_PASSWD_MAX_DB_SIZE
$NSCD_PASSWD_AUTO_PROPAGATE

$NSCD_GROUP_ENABLE_CACHE
$NSCD_GROUP_POSITIVE_TTL
$NSCD_GROUP_NEGATIVE_TTL
$NSCD_GROUP_SUGGESTED_SIZE
$NSCD_GROUP_CHECK_FILES
$NSCD_GROUP_PERSISTENT
$NSCD_GROUP_SHARED
$NSCD_GROUP_MAX_DB_SIZE
$NSCD_GROUP_AUTO_PROPAGATE

$NSCD_HOSTS_ENABLE_CACHE
$NSCD_HOSTS_POSITIVE_TTL
$NSCD_HOSTS_NEGATIVE_TTL
$NSCD_HOSTS_SUGGESTED_SIZE
$NSCD_HOSTS_CHECK_FILES
$NSCD_HOSTS_PERSISTENT
$NSCD_HOSTS_SHARED
$NSCD_HOSTS_MAX_DB_SIZE    
EOF
    echo "[$INFO] ... the $NSCD_FILE file has been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "[$INFO] ... restarting the nscd service." | tee -a $LOG_FILE
    service $NSCD_SERVICE restart
    echo "" | tee -a $LOG_FILE
}

#  create the new /etc/krb5.conf file function:
createKrb5Conf (){
    echo ">>> STEP 24 - $DATE_02 - BEGIN CONFIGURE /ETC/KRB5.CONF" | tee -a $LOG_FILE
    #  ...clear out the current /etc/krb5.conf file
    > $KRB5_FILE
    #  ...create the new /etc/krb5.conf file
	#  ...please note that a domain with more than one kdc and admin_server
	#+ ...would look like this:
	#  kdc = $DC_01_FQDN:88
	#  kdc = $DC_02_FQDN:88
	#  admin_server = $DC_01_FQDN:749
	#  admin_server = $DC_02_FQDN:749
    cat <<EOF > $KRB5_FILE
### THIS FILE CREATED BY THE DEVCENTER MAGICLAMP PROJECT ON $DATE ###
[logging]
 default = $KRB5_DEFAULT_LOG
 kdc = $KRB5_KDC_LOG
 admin_server = $KRB5_ADMIN_SERVER_LOG

[libdefaults]
 default_realm = $DOMAIN_NAME_02
 dns_lookup_realm = $KRB5_DNS_LOOKUP_REALM 
 dns_lookup_kdc = $KRB5_DNS_LOOKUP_KDC 
 ticket_lifetime = $KRB5_TICKET_LIFETIME_01
 renew_lifetime = $KRB5_RENEW_LIFETIME_01
 forwardable = $KRB5_FORWARDABLE_01
 validate = $KRB5_VALIDATE_01 

[realms]
 $DOMAIN_NAME_02 = {
  kdc = $DC_01_FQDN:88
  kdc = $DC_02_FQDN:88
  admin_server = $DC_01_FQDN:749
  admin_server = $DC_02_FQDN:749
  default_domain = $DOMAIN_NAME_01
 }

[domain_realm]
 .$DOMAIN_NAME_01 = $DOMAIN_NAME_02
 $DOMAIN_NAME_01 = $DOMAIN_NAME_02

[appdefaults]
 pam = {
   debug = false
   ticket_lifetime = $KRB5_TICKET_LIFETIME_02
   renew_lifetime = $KRB5_RENEW_LIFETIME_02
   forwardable = $KRB5_FORWARDABLE_02
   krb4_convert = $KRB4_CONVERT_01
   validate = $KRB5_VALIDATE_02
 }
EOF
    echo "[$INFO] ... the $KRB5_FILE file has been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  create the new /etc/pam.d/system-auth file function:
createPamSystemAuth (){
    echo ">>> STEP 25 - $DATE_02 - BEGIN CONFIGURE /ETC/PAM.D/SYSTEM-AUTH" | tee -a $LOG_FILE
    #  ...empty the current /etc/pam.d/system-auth file
    > $PAM_FILE
    #  ...cCreate the new /etc/pam.d/system-auth file
    cat <<EOF > $PAM_FILE
### THIS FILE CREATED BY THE DEVCENTER MAGICLAMP PROJECT ON $DATE ###
#%PAM-1.0
# User changes will be destroyed the next time authconfig is run.
auth        required      pam_env.so
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 500 quiet
auth        sufficient    pam_krb5.so use_first_pass ignore_root minimum_uid=1000
auth        required      pam_deny.so

account     required      pam_access.so
account     required      pam_unix.so broken_shadow
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 500 quiet
account     [default=bad success=ok user_unknown=ignore] pam_krb5.so
account     required      pam_permit.so

password    requisite     pam_cracklib.so try_first_pass retry=3 type=
password    sufficient    pam_unix.so md5 shadow nullok try_first_pass use_authtok
password    sufficient    pam_krb5.so use_authtok
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
session     optional      pam_mkhomedir.so skel=/etc/skel/ umask=0022
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
session     optional      pam_krb5.so
EOF
    echo "[$INFO] ... the $PAM_FILE file has been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  create the new /etc/ldap.conf and /etc/openldap/ldap.conf files function:
createOpenLdapConf (){
    echo ">>> STEP 26 - $DATE_02 - START CONFIGURE /ETC/LDAP.CONF AND /ETC/OPENLDAP/LDAP.CONF" | tee -a $LOG_FILE
    #  ...empty the current /etc/ldap.conf and /etc/openldap/ldap.conf files
    > $LDAP_FILE
    > $OPENLDAP_FILE
    #  ...create the new /etc/ldap.conf file
	#  ...please note that a setup with more than one BASE value would
	#+ ...look like this: BASE dc=$DN_BASE_01,dc=$DN_BASE_02
    cat <<EOF > $LDAP_FILE
### THIS FILE CREATED BY THE DEVCENTER MAGICLAMP PROJECT ON $DATE ###
# /etc/ldap.conf (RHEL 5 ONLY)
base dc=$DN_BASE_01
port $LDAP_PORT
timelimit $LDAP_TIMELIMIT
bind_timelimit $LDAP_BIND_TIMELIMIT
bind_policy $LDAP_BIND_POLICY
idle_timelimit $LDAP_IDLE_TIMEOUT
nss_base_passwd         $LDAP_NSS_BASE_PASSWD
nss_base_shadow         $LDAP_NSS_BASE_SHADOW
nss_base_group          $LDAP_NSS_BASE_GROUP
nss_base_hosts          $LDAP_NSS_BASE_HOSTS
nss_initgroups_ignoreusers $LDAP_NSS_INITGROUPS_IGNORE_USERS
nss_map_objectclass posixAccount $LDAP_NSS_MAP_OBJECTCLASS_POSIXACCOUNT
nss_map_objectclass shadowAccount $LDAP_NSS_MAP_OBJECTCLASS_SHADOWACCOUNT
nss_map_objectclass posixGroup $LDAP_NSS_MAP_OBJECTCLASS_POSIXGROUP
nss_map_attribute uid $LDAP_NSS_MAP_ATTRIBUTE_UID
nss_map_attribute uidNumber $LDAP_NSS_MAP_ATTRIBUTE_UIDNUMBER
nss_map_attribute gidNumber $LDAP_NSS_MAP_ATTRIBUTE_GIDNUMBER
nss_map_attribute loginShell $LDAP_NSS_MAP_ATTRIBUTE_LOGINSHELL
nss_map_attribute gecos $LDAP_NSS_MAP_ATTRIBUTE_GECOS
nss_map_attribute homeDirectory $LDAP_NSS_MAP_ATTRIBUTE_HOME_DIRECTORY
nss_map_attribute shadowLastChange $LDAP_NSS_MAP_ATTRIBUTE_SHADOWLASTCHANGE
nss_map_attribute uniqueMember $LDAP_NSS_MAP_ATTRIBUTE_UNIQUEMEMBER
pam_login_attribute $LDAP_PAM_LOGIN_ATTRIBUTE
pam_member_attribute $LDAP_PAM_MEMBER_ATTRIBUTE_NAME
pam_filter objectclass=$LDAP_PAM_FILTER_OBJECTCLASS
pam_password $LDAP_PAM_PASSWORD
uri $LDAP_URI
ssl $LDAP_SSL
tls_cacertdir $LDAP_TLS_CACERTDIR
sasl_secprops maxssf=$LDAP_SASL_SECPROPS_MAXSSF
use_sasl $LDAP_USE_SASL
rootuse_sasl $LDAP_ROOTUSE_SASL
krb5_ccname $LDAP_KRB5_CCNAME
# these setting prevent system hang when LDAP is unavailable
bind_timeout $LDAP_BIND_TIMEOUT
nss_reconnect_tries $LDAP_NSS_RECONNECT_TRIES
nss_reconnect_sleeptime $LDAP_NSS_RECONECT_SLEEPTIME
nss_reconnect_maxsleeptime $LDAP_NSS_RECONNECT_MAXSLEEPTIME
nss_reconnect_maxconntries $LDAP_NSS_RECONNECT_MAXCONNTRIES
EOF
    #  ...create the /etc/openldap/ldap.conf file
    cat <<EOF > $OPENLDAP_FILE
### THIS FILE CREATED BY THE DEVCENTER MAGICLAMP PROJECT ON $DATE ###
#
# LDAP Defaults
#

# See ldap.conf(5) for details
# This file should be world readable but not world writable.

#BASE   dc=example, dc=com
#URI    ldap://ldap.example.com ldap://ldap-master.example.com:666

#SIZELIMIT      12
#TIMELIMIT      15
#DEREF          never
TLS_CACERTDIR $LDAP_TLS_CACERTDIR
URI $LDAP_URI
BASE dc=$DN_BASE_01,dc=$DN_BASE_02
EOF
    echo "[$INFO] ... the $LDAP_FILE and $OPENLDAP_FILE files have been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  create the new /etc/nsswitch.conf file function:
createNsswitchConf (){
    echo ">>> STEP 27 - $DATE_02 - BEGIN CONFIGURE /ETC/NSSWITCH.CONF" | tee -a $LOG_FILE
    #  ...empty the current /etc/nsswitch.conf file
    > $NSSWITCH_FILE
    #  ...create the /etc/nsswitch.conf file
	#  ...please note that this setup includes hosts information from:  files dns ldap
    #  ...if you do not intend to use ldap to store host information then remove 'ldap'
	#+ ...from the "hosts:" line
    cat <<EOF > $NSSWITCH_FILE
### THIS FILE CREATED BY THE DEVCENTER MAGICLAMP PROJECT ON $DATE ###
#
# /etc/nsswitch.conf
#
# An example Name Service Switch config file. This file should be
# sorted with the most-used services at the beginning.
#
# The entry '[NOTFOUND=return]' means that the search for an
# entry should stop if the search in the previous entry turned
# up nothing. Note that if the search failed due to some other reason
# (like no NIS server responding) then the search continues with the
# next entry.
#
# Legal entries are:
#
#       nisplus or nis+         Use NIS+ (NIS version 3)
#       nis or yp               Use NIS (NIS version 2), also called YP
#       dns                     Use DNS (Domain Name Service)
#       files                   Use the local files
#       db                      Use the local database (.db) files
#       compat                  Use NIS on compat mode
#       hesiod                  Use Hesiod for user lookups
#       [NOTFOUND=return]       Stop searching if not found so far
#

# To use db, put the "db" in front of "files" for entries you want to be
# looked up first in the databases
#
# Example:
#passwd:    db files nisplus nis
#shadow:    db files nisplus nis
#group:     db files nisplus nis

$NSSWITCH_PASSWD
$NSSWITCH_SHADOW
$NSSWITCH_GROUP

#hosts:     db files nisplus nis dns
$NSSWITCH_HOSTS

# Example - obey only what nisplus tells us...
#services:   nisplus [NOTFOUND=return] files
#networks:   nisplus [NOTFOUND=return] files
#protocols:  nisplus [NOTFOUND=return] files
#rpc:        nisplus [NOTFOUND=return] files
#ethers:     nisplus [NOTFOUND=return] files
#netmasks:   nisplus [NOTFOUND=return] files     

$NSSWITCH_BOOTPARAMS

$NSSWITCH_ETHERS
$NSSWITCH_NETMASKS
$NSSWITCH_NETWORKS
$NSSWITCH_PROTOCOLS
$NSSWITCH_RPC
$NSSWITCH_SERVICES

$NSSWITCH_NETGROUP

$NSSWITCH_PUBLICKEY

$NSSWITCH_AUTOMOUNT
$NSSWITCH_ALIASES

$NSSWITCH_SUDOERS
EOF
    echo "[$INFO] ... the $NSSWITCH_FILE file has been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  create the new /etc/idmapd.conf file function:
createIdmapdConf (){
    echo ">>> STEP 28 - $DATE_02 - BEGIN CONFIGURE /ETC/IDMAPD.CONF" | tee -a $LOG_FILE
    #  ...empty the current /etc/idmapd.conf file
    > $IDMAPD_FILE
    cat <<EOF > $IDMAPD_FILE
### THIS FILE CREATED BY THE DEVCENTER MAGICLAMP PROJECT ON $DATE ###
[General]
#Verbosity = 0
# The following should be set to the local NFSv4 domain name
# The default is the host's DNS domain name.
#Domain = local.domain.edu
Domain = $IDMAPD_DOMAIN

# The following is a comma-separated list of Kerberos realm
# names that should be considered to be equivalent to the
# local realm, such that <user>@REALM.A can be assumed to
# be the same user as <user>@REALM.B
# If not specified, the default local realm is the domain name,
# which defaults to the host's DNS domain name,
# translated to upper-case.
# Note that if this value is specified, the local realm name
# must be included in the list!
#Local-Realms =
Local=Realms = $IDMAPD_REALMS

[Mapping]

Nobody-User = $IDMAPD_NOBODY_USER
Nobody-Group = $IDMAPD_NOBODY_GROUP

[Translation]

# Translation Method is an comma-separated, ordered list of
# translation methods that can be used.  Distributed methods
# include "nsswitch", "umich_ldap", and "static".  Each method
# is a dynamically loadable plugin library.
# New methods may be defined and inserted in the list.
# The default is "nsswitch".
Method = nsswitch

# Optional.  This is a comma-separated, ordered list of
# translation methods to be used for translating GSS
# authenticated names to ids.
# If this option is omitted, the same methods as those
# specified in "Method" are used.
#GSS-Methods = <alternate method list for translating GSS names>
 
#-------------------------------------------------------------------#
# The following are used only for the "static" Translation Method.
#-------------------------------------------------------------------#
[Static]

# A "static" list of GSS-Authenticated names to
# local user name mappings

#someuser@REALM = localuser

#-------------------------------------------------------------------#
# The following are used only for the "umich_ldap" Translation Method.
#-------------------------------------------------------------------#

#[UMICH_SCHEMA]

# server information (REQUIRED)
#LDAP_server = ldap-server.local.domain.edu

# the default search base (REQUIRED)
#LDAP_base = dc=local,dc=domain,dc=edu

#-----------------------------------------------------------#
# The remaining options have defaults (as shown)
# and are therefore not required.
#-----------------------------------------------------------#

# whether or not to perform canonicalization on the
# name given as LDAP_server
#LDAP_canonicalize_name = true

# absolute search base for (people) accounts
#LDAP_people_base = <LDAP_base>

# absolute search base for groups
#LDAP_group_base = <LDAP_base>

# Set to true to enable SSL - anything else is not enabled
#LDAP_use_ssl = false

# You must specify a CA certificate location if you enable SSL
#LDAP_ca_cert = /etc/ldapca.cert

# Objectclass mapping information

# Mapping for the person (account) object class
#NFSv4_person_objectclass = NFSv4RemotePerson

# Mapping for the nfsv4name attribute the person object
#NFSv4_name_attr = NFSv4Name

# Mapping for the UID number
#NFSv4_uid_attr = UIDNumber

# Mapping for the GSSAPI Principal name
#GSS_principal_attr = GSSAuthName

# Mapping for the account name attribute (usually uid)
# The value for this attribute must match the value of 
# the group member attribute - NFSv4_member_attr
#NFSv4_acctname_attr = uid

# Mapping for the group object class
#NFSv4_group_objectclass = NFSv4RemoteGroup

# Mapping for the GID attribute
#NFSv4_gid_attr = GIDNumber

# Mapping for the Group NFSv4 name
#NFSv4_group_attr = NFSv4Name

# Mapping for the Group member attribute (usually memberUID)
# The value of this attribute must match the value of NFSv4_acctname_attr
#NFSv4_member_attr = memberUID
EOF
    echo "[$INFO] ... the $IDMAPD_FILE file has been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  create the active directory nfsv4 service using msktutil function:
createADNFSv4Service (){
    echo ">>> STEP 29 - $DATE_02 - BEGIN CREATE ACTIVE DIRECTORY NFSV4 SERVICE OBJECT" | tee -a $LOG_FILE
    #  ...request Kerberos ticket for Active Directory user with rights to join computer objects to the domain
    /usr/kerberos/bin/kinit $ADMIN_USERNAME
    #  ...user will be prompted for the Active Directory username provided
    #  ...remove any existing /etc/krb5.keytab file
    if [ -e $KRB5_LDAP_KEYTAB ];
    then
        rm $KRB5_LDAP_KEYTAB
    fi
    #  ...create the computer-spceific NFSv4 service principle object (SPN) and user principle object (UiPN)
    #/usr/sbin/msktutil --delegation --no-pac --computer-name $HOST_NAME-nfs --enctypes 0x1C -b "$MSKTUTIL_COMPUTER_OU_02" -k $KRB5_NFSV4_KEYTAB -h $HOSTFQDN -s nfs/$HOSTFQDN --upn nfs/$HOSTFQDN  --description "$NFSV4_MAIN_DESCRIPTION" --verbose
    /usr/sbin/msktutil --delegation --dont-expire-password --computer-name $HOST_NAME-nfs --enctypes 0x1C -b "$MSKTUTIL_COMPUTER_OU_02" -k $KRB5_LDAP_KEYTAB -h $HOSTFQDN -s nfs/$HOSTFQDN --upn nfs/$HOSTFQDN --verbose --description "$NFSV4_MAIN_DESCRIPTION" | tee -a $LOG_FILE
    echo "[$INFO] ... NFSv4 service object for $HOSTFQDN has been created in Active Directory OU: $MSKTUTIL_COMPUTER_OU_02." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    kdestroy
}

#  create the active directory computer objects using msktutil function:
createADComputerObject (){
    echo ">>> STEP 30 - $DATE_02 - BEGIN CREATE COMPUTER OBJECT AND JOIN ACTIVE DIRECTORY DOMAIN" | tee -a $LOG_FILE
    #  ...request Kerberos ticket for Active Directory user with rights to join computer objects to the domain
    /usr/kerberos/bin/kinit $ADMIN_USERNAME
    #  ...user will be prompted for the Active Directory username provided
    #  ...we're adding to the existing /etc/krb5.keytab so we won't remove any existing /etc/krb5.keytab file
    #  ...create the Active Directory computer object service principle name (SPN) and user principle name (UPN)
    /usr/sbin/msktutil --delegation --dont-expire-password --computer-name $HOST_NAME --enctypes 0x1C -b "$MSKTUTIL_COMPUTER_OU_01" -k $KRB5_LDAP_KEYTAB -h $HOSTFQDN -s host/$HOSTFQDN -s host/$HOST_NAME --upn host/$HOSTFQDN --verbose --description "$RHEL5_MAIN_DESCRIPTION" | tee -a $LOG_FILE
    echo "[$INFO] ... computer object for $HOSTFQDN has been created in Active Directory OU: $MSKTUTIL_COMPUTER_OU_01" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    kdestroy
}

#  create new /etc/sysconfig/nfs file function:
createSysconfigNfs (){
    echo ">>> STEP 31 - $DATE_02 - BEGIN CONFIGURE /ETC/SYSCONFIG/NFS" | tee -a $LOG_FILE
    #  ...empty the current /etc/sysconfig/nfs file
    > $SYSCONFIG_NFS_FILE
    #  ...create the /etc/sysconfig/nfs file
    cat <<EOF > $SYSCONFIG_NFS_FILE
### THIS FILE CREATED BY THE DEVCENTER MAGICLAMP PROJECT ON $DATE ###
#
# Define which protocol versions mountd 
# will advertise. The values are "no" or "yes"
# with yes being the default
#MOUNTD_NFS_V1="no"
#MOUNTD_NFS_V2="no"
#MOUNTD_NFS_V3="no"
#
#
# Path to remote quota server. See rquotad(8)
#RQUOTAD="/usr/sbin/rpc.rquotad"
# Port rquotad should listen on.
#RQUOTAD_PORT=875
# Optinal options passed to rquotad
#RPCRQUOTADOPTS=""
#
# Optional arguments passed to in-kernel lockd
#LOCKDARG=
# TCP port rpc.lockd should listen on.
#LOCKD_TCPPORT=32803
# UDP port rpc.lockd should listen on.
#LOCKD_UDPPORT=32769
#
#
# Optional arguments passed to rpc.nfsd. See rpc.nfsd(8)
# Turn off v2 and v3 protocol support
#RPCNFSDARGS="-N 2 -N 3"
# Turn off v4 protocol support
#RPCNFSDARGS="-N 4"
# Number of nfs server processes to be started.
# The default is 8. 
#RPCNFSDCOUNT=8
# Stop the nfsd module from being pre-loaded 
#NFSD_MODULE="noload"
#
#
# Optional arguments passed to rpc.mountd. See rpc.mountd(8)
#RPCMOUNTDOPTS=""
# Port rpc.mountd should listen on.
#MOUNTD_PORT=892
#
#
# Optional arguments passed to rpc.statd. See rpc.statd(8)
#STATDARG=""
# Port rpc.statd should listen on.
#STATD_PORT=662
# Outgoing port statd should used. The default is port
# is random
#STATD_OUTGOING_PORT=2020
# Specify callout program 
#STATD_HA_CALLOUT="/usr/local/bin/foo"
#
#
# Optional arguments passed to rpc.idmapd. See rpc.idmapd(8)
#RPCIDMAPDARGS=""
#
# Set to turn on Secure NFS mounts. 
#SECURE_NFS="yes"
# Optional arguments passed to rpc.gssd. See rpc.gssd(8)
#RPCGSSDARGS="-vvv"
# Optional arguments passed to rpc.svcgssd. See rpc.svcgssd(8)
#RPCSVCGSSDARGS="-vvv"
# Don't load security modules in to the kernel
#SECURE_NFS_MODS="noload"
#
# Don't load sunrpc module.
#RPCMTAB="noload"
#
$NFS_MOUNTD_NFS_V1
$NFS_MOUNTD_NFS_V2
MOUNTD_NFS_V3="$NFS_MOUNTD_NFS_V3"
RPCNFSDCOUNT=$NFS_RPCNFSDCOUNT
LOCKD_TCPPORT=$NFS_LOCKD_TCPPORT
LOCKD_UDPPORT=$NFS_LOCKD_UDPPORT
STATD_PORT=$NFS_STATD_PORT
STATD_OUTGOING_PORT=$NFS_STATD_OUTGOING_PORT
MOUNTD_PORT=$NFS_MOUNTD_PORT
RQUOTAD_PORT=$NFS_RQUOTAD_PORT
SECURE_NFS="$NFS_SECURE_NFS"
RPCGSSDARGS="$NFS_RPCGSSDARGS"
RPCSVCGSSDARGS="$NFS_RPCSVCGSSDARGS"
EOF
	echo "[$INFO] ... the $SYSCONFIG_NFS_FILE file has been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  create new /etc/sysconfig/autofs file function:
createSysconfigAutofs (){
    echo ">>> STEP 32 - $DATE_02 - BEGIN CONFIGURE /ETC/SYSCONFIG/AUTOFS" | tee -a $LOG_FILE
    #  ...empty the current /etc/sysconfig/nfs file
    > $SYSCONFIG_AUTOFS_FILE
    #  ...create the /etc/sysconfig/nfs file
    cat <<EOF > $SYSCONFIG_AUTOFS_FILE
### THIS FILE CREATED BY THE DEVCENTER MAGICLAMP PROJECT ON $DATE ###
#
# Define default options for autofs.
#
# MASTER_MAP_NAME - default map name for the master map.
#
#MASTER_MAP_NAME="auto.master"
#
# TIMEOUT - set the default mount timeout (default 600).
#
#TIMEOUT=300
#
# NEGATIVE_TIMEOUT - set the default negative timeout for
#                    failed mount attempts (default 60).
#
#NEGATIVE_TIMEOUT=60
#
# MOUNT_WAIT - time to wait for a response from umount(8).
#              Setting this timeout can cause problems when
#              mount would otherwise wait for a server that
#              is temporarily unavailable, such as when it's
#              restarting. The defailt of waiting for mount(8)
#              usually results in a wait of around 3 minutes.
#
#MOUNT_WAIT=-1
#
# UMOUNT_WAIT - time to wait for a response from umount(8).
#
#UMOUNT_WAIT=12
#
# BROWSE_MODE - maps are browsable by default.
#
#BROWSE_MODE="no"
#
# APPEND_OPTIONS - append to global options instead of replace.
#
#APPEND_OPTIONS="yes"
#
# LOGGING - set default log level "none", "verbose" or "debug"
#
#LOGGING="none"
#
# Define base dn for map dn lookup.
#
# Define server URIs
#
# LDAP_URI - space seperated list of server uris of the form
#            <proto>://<server>[/] where <proto> can be ldap
#            or ldaps. The option can be given multiple times.
#            Map entries that include a server name override
#            this option.
#
#            This configuration option can also be used to
#            request autofs lookup SRV RRs for a domain of
#            the form <proto>:///[<domain dn>]. Note that a
#            trailing "/" is not allowed when using this form.
#            If the domain dn is not specified the dns domain
#            name (if any) is used to construct the domain dn
#            for the SRV RR lookup. The server list returned
#            from an SRV RR lookup is refreshed according to
#            the minimum ttl found in the SRV RR records or
#            after one hour, whichever is less.
#
#LDAP_URI=""
#
# LDAP__TIMEOUT - timeout value for the synchronous API  calls
#                 (default is LDAP library default).
#
#LDAP_TIMEOUT=-1
#
# LDAP_NETWORK_TIMEOUT - set the network response timeout (default 8).
#
#LDAP_NETWORK_TIMEOUT=8
#
# SEARCH_BASE - base dn to use for searching for map search dn.
#               Multiple entries can be given and they are checked
#               in the order they occur here.
#
#SEARCH_BASE=""
#
# Define the LDAP schema to used for lookups
#
# If no schema is set autofs will check each of the schemas
# below in the order given to try and locate an appropriate
# basdn for lookups. If you want to minimize the number of
# queries to the server set the values here.
#
MASTER_MAP_NAME="$AUTOFS_MASTER_MAP_NAME"
TIMEOUT=$AUTOFS_TIMEOUT
BROWSE_MODE="$AUTOFS_BROWSE_MODE"
LDAP_URI="$AUTOFS_LDAP_URI"
SEARCH_BASE="$AUTOFS_SEARCH_BASE"
MAP_OBJECT_CLASS="$AUTOFS_MAP_OBJECT_CLASS"
ENTRY_OBJECT_CLASS="$AUTOFS_ENTRY_OBJECT_CLASS"
MAP_ATTRIBUTE="$AUTOFS_MAP_ATTRIBUTE"
ENTRY_ATTRIBUTE="$AUTOFS_ENTRY_ATTRIBUTE"
VALUE_ATTRIBUTE="$AUTOFS_VALUE_ATTRIBUTE"
AUTH_CONF_FILE="$AUTOFS_AUTH_CONF_FILE"
USE_MISC_DEVICE="$AUTOFS_USE_MISC_DEVICE"
#
# Other common LDAP naming
#
#MAP_OBJECT_CLASS="automountMap"
#ENTRY_OBJECT_CLASS="automount"
#MAP_ATTRIBUTE="ou"
#ENTRY_ATTRIBUTE="cn"
#VALUE_ATTRIBUTE="automountInformation"
#
#MAP_OBJECT_CLASS="automountMap"
#ENTRY_OBJECT_CLASS="automount"
#MAP_ATTRIBUTE="automountMapName"
#ENTRY_ATTRIBUTE="automountKey"
#VALUE_ATTRIBUTE="automountInformation"
#
# AUTH_CONF_FILE - set the default location for the SASL
#                          authentication configuration file.
#
#AUTH_CONF_FILE="/etc/autofs_ldap_auth.conf"
#
# MAP_HASH_TABLE_SIZE - set the map cache hash table size.
#                       Should be a power of 2 with a ratio roughly
#                       between 1:10 and 1:20 for each map.
#
#MAP_HASH_TABLE_SIZE=1024
#
# General global options
#
# If the kernel supports using the autofs miscellanous device
# and you wish to use it you must set this configuration option
# to "yes" otherwise it will not be used.
#USE_MISC_DEVICE="yes"
#
#OPTIONS=""
#
EOF
    echo "[$INFO] ... the $SYSCONFIG_AUTOFS_FILE file has been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}
    
#  create msktutil ad change computer password crontab function:
createAdChangeComputerPasswordCron (){
    echo ">>> STEP 33 - $DATE_02 - BEGIN SCHEDULE MSKTUTIL CHECK COMPUTER PASSWORD CRON JOB" | tee -a $LOG_FILE
    #  ..backup current crontab
    echo "[$INFO] ... backing up current root crontab to $CRON_BACKUP_DIR/$CRON_BACKUP_NAME" | tee -a $LOG_FILE
    cp $CRON_FILE /$CRON_BACKUP_DIR/$CRON_BACKUP_NAME
	#  ...clear out the current crontab
	> $CRON_FILE
    #  ..add new crontab entry
    echo "[$INFO] ... adding msktutil computer password change cron job." | tee -a $LOG_FILE
    echo "15 3 * * * /usr/sbin/msktutil -b ou=servers,ou=lux --auto-update" | tee -a $LOG_FILE
    echo "15 3 * * * /usr/sbin/msktutil -b ou=servers,ou=lux --auto-update" >> $CRON_FILE
    echo "[$INFO] ... your current crontab is now:" | tee -a $LOG_FILE
    cat $CRON_FILE | tee -a $LOG_FILE
    echo "[$PASS] ... the msktutil change computer password cron job added." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  create msktutil ad change nfsv4 service password crontab function:
createAdChangeNFSv4ServicePasswordCron (){
    echo ">>> STEP 34 - $DATE_02 - BEGIN SCHEDULE MSKTUTIL CHECK NFSV4 SERVICE PASSWORD CRON JOB" | tee -a $LOG_FILE
    #  ..backup currnet crontab
    echo "[$INFO] ... backing up current root crontab to $CRON_BACKUP_DIR/$CRON_BACKUP_NAME" | tee -a $LOG_FILE
    cp $CRON_FILE /$CRON_BACKUP_DIR/$CRON_BACKUP_NAME
    #  ..add new crontab entry
    echo "[$INFO] ... adding msktutil computer password change cron job." | tee -a $LOG_FILE
    echo "15 3 * * * /usr/sbin/msktutil -h $COMPUTERNAME-nfs -b ou=services,ou=servers,ou=lux --auto-update" | tee -a $LOG_FILE
    echo "15 3 * * * /usr/sbin/msktutil -h $COMPUTERNAME-nfs -b ou=services,ou=servers,ou=lux --auto-update" >> $CRON_FILE
    echo "[$INFO] ... your current crontab is now:" | tee -a $LOG_FILE
    cat $CRON_FILE | tee -a $LOG_FILE
    echo "[$PASS] ... the msktutil change nfsv4 service password cron job added." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}


#  start the k5start_ldap service and set service run levels function:
startK5startLdap (){
    echo ">>> STEP 35 - $DATE_02 - BEGIN START AND CONFIGURE K5START_LDAP SERVICE" | tee -a $LOG_FILE
    #  ...start the k5start_ldap service
    OUTPUT=$(ps aux | grep -v grep | grep $K5START_LDAP_SERVICE)
    if [ "${#OUTPUT}" -lt 1 ];
    then
        echo "[$PASS] ... the $K5START_LDAP_SERVICE service is stopped...starting the service."  | tee -a $LOG_FILE
        service $K5START_LDAP_SERVICE start
    else
        echo "[$PASS] ... the $K5START_LDAP_SERVICE service is already running." | tee -a $LOG_FILE
    fi
    #  ...configure the k5start_ldap service level runtimes
    chkconfig $K5START_LDAP_SERVICE on
    echo "[$INFO] ... the $K5START_LDAP_SERVICE service is configured for run-levels:" | tee -a $LOG_FILE
    echo `chkconfig $K5START_LDAP_SERVICE --list` | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  start the k5start_ldap service and set service run levels function:
startK5startNfsv4 (){
    echo ">>> STEP 36 - $DATE_02 - BEGIN START AND CONFIGURE K5START_NFSV4 SERVICE" | tee -a $LOG_FILE
    #  ...start the k5start_nfsv4 service
    OUTPUT=$(ps aux | grep -v grep | grep $K5START_NFSV4_SERVICE)
    if [ "${#OUTPUT}" -lt 1 ];
    then
        echo "[$PASS] ... the $K5START_NFSV4_SERVICE service is stopped...starting the service."  | tee -a $LOG_FILE
        service $K5START_NFSV4_SERVICE start
    else
        echo "[$PASS] ... the $K5START_NFSV4_SERVICE service is already running." | tee -a $LOG_FILE
    fi
    #  ...configure the k5start_ldap service level runtimes
    chkconfig $K5START_NFSV4_SERVICE on
    echo "[$INFO] ... the $K5START_NFSV4_SERVICE service is configured for run-levels:" | tee -a $LOG_FILE
    echo `chkconfig $K5START_NFSV4_SERVICE --list` | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  query ldap for user data function:
queryAdUser (){
    echo ">>> STEP 37 - $DATE_02 - BEGIN TEST LDAP QUERY" | tee -a $LOG_FILE
    #  ...test using getent passwd
    #  ...request Kerberos ticket for Active Directory user with query objects in the domain
    /usr/kerberos/bin/kinit $ADMIN_USERNAME
    echo "[$INFO] ... these tests expect that an user named $AD_TESTUSER_01 exist in your active directory domain." | tee -a $LOG_FILE
    echo "[$INFO] ... in addtion, the second test expects that the employeeID active directory schema value has been set." | tee -a $LOG_FILE
    echo "[$INFO] ... testing getent passwd $AD_TESTUSER_01 against $KRB5_REALM_01:" | tee -a $LOG_FILE
    OUTPUT_01=$(/usr/bin/getent passwd $AD_TESTUSER_01)
    if [ "${#OUTPUT_01}" -lt 1 ];
    then
        echo "[$FAIL] ... unable to retrieve getent data for $AD_TESTUSER_01." | tee -a $LOG_FILE
    else
        echo "[$PASS] ... "`/usr/bin/getent passwd $AD_TESTUSER_01`| tee -a $LOG_FILE
    fi
    #  ...test using ldapsearch
    echo "[$INFO] ... testing ldap search for $AD_TESTUSER_01 against $KRB5_REALM_01 domain controllers:" | tee -a $LOG_FILE
    OUTPUT_02=$(/usr/bin/ldapsearch cn=$AD_TESTUSER_01 2>&1 | grep ^employeeID)
    if [ "${#OUTPUT_02}" -lt 1 ];
    then
        echo "[$FAIL] ... unable to retrieve the Active Directory employeeID value for $AD_TESTUSER_01." | tee -a $LOG_FILE
    else
        echo "[$PASS] ... the active directory employeeID value for $AD_TESTUSER_01 is - $OUTPUT_02" | tee -a $LOG_FILE
    fi
    kdestroy
    echo "" | tee -a $LOG_FILE
}

#  destroy the kerberos ticket acquire earlier for the active directory user function:
destroyKerberosTicket (){
    echo ">>> STEP 38 - $DATE_02 - BEGIN KDESTROY TO REMOVE KERBEROS TICKET" | tee -a $LOG_FILE
    kdestroy
    echo "[$INFO] ... the kerberos ticket previously acquired for $ADMIN_NAME has been destroyed." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  configure the new /etc/autofs_ldap_auth.conf file function:
createAutoFSLdapAuthConf (){
    echo ">>> STEP 39 - $DATE_02 - BEGIN CONFIGURE /ETC/AUTOFS_LDAP_AUTH.CONF" | tee -a $LOG_FILE
    # ...empty the contents fo the current /etc/autofs_ldap_auth.conf file
    > $AUTOFS_LDAP_AUTH_FILE
    #  ...create new /etc/autofs_ldap_auth.conf file
    cat <<EOF > $AUTOFS_LDAP_AUTH_FILE
<?xml version="1.0" ?>
<!--
This files contains a single entry with multiple attributes tied to it.
The attributes are:

usetls  -  Determines whether an encrypted connection to the ldap server
           should be attempted.  Legal values for the entry are:
           "yes"
           "no"

tlsrequired  -  This flag tells whether the ldap connection must be
           encrypted.  If set to "yes", the automounter will fail to start
           if an encrypted connection cannot be established.  Legal values
           for this option include:
           "yes"
           "no"

authrequired  -  This option tells whether an authenticated connection to
            the ldap server is required in order to perform ldap queries.
            If the flag is set to yes, only sasl authenticated connections
            will be allowed. If it is set to no then authentication is not
            needed for ldap server connections. If it is set to autodetect
            then the ldap server will be queried to establish a suitable
            sasl authentication mechanism. If no suitable mechanism can be
            found, connections to the ldap server are made without
            authentication. Finally, if it is set to simple, then simple
            authentication will be used instead of SASL.

            Legal values for this option include:
            "yes"
            "no"
            "autodetect"
            "simple"

authtype  -  This attribute can be used to specify a preferred
            authentication mechanism.  In normal operations, the
            automounter will attempt to authenticate to the ldap server
            using the list of supportedSASLmechanisms obtained from the
            directory server.  Explicitly setting the authtype will bypass
            this selection and only try the mechanism specified. The
            EXTERNAL mechanism may be used to authenticate using a client
            certificate and requires that authrequired set to "yes" if
            using SSL or usetls, tlsrequired and authrequired all set to
            "yes" if using TLS, in addition to authtype being set EXTERNAL.

            Legal values for this attribute include:
            "GSSAPI"
            "LOGIN"
            "PLAIN"
            "ANONYMOUS"
            "DIGEST-MD5"
            "EXTERNAL"

            If using authtype EXTERNAL two additional configuration entries
            are required:

            external_cert="<client certificate path>"

            This specifies the path of the file containing the client
            certificate.

            external_key="<client certificate key path>"

            This specifies the path of the file containing the client
            certificate key.

            These two configuration entries are mandatory when using the
            EXTERNAL method as the HOME environment variable cannot be
            assumed to be set or, if it is, to be set to the location we
            expect.

user  -  This attribute holds the authentication identity used by
            authentication mechanisms that require it.  Legal values for
            this attribute include any printable characters that can be
            used by the selected authentication mechanism.

secret  -  This attribute holds the secret used by authentication
            mechanisms that require it.  Legal values for this attribute
            include any printable characters that can be used by the
            selected authentication mechanism.

encoded_secret  -  This attribute holds the base64 encoded secret used
            by authentication mechanisms that require it. If this entry
            is present as well as the secret entry this value will take
            precedence.

clientprinc  -  When using GSSAPI authentication, this attribute is
            consulted to determine the principal name to use when
            authenticating to the directory server.  By default, this will
            be set to "autofsclient/<fqdn>@<REALM>.

credentialcache - When using GSSAPI authentication, this attribute
            can be used to specify an externally configured credential
            cache that is used during authentication. By default, autofs
            will setup a memory based credential cache.
-->

<autofs_ldap_sasl_conf
        usetls="$USE_TLS"
        tlsrequired="$TLS_REQUIRED"
        authrequired="$AUTH_REQUIRED"
        authtype="$AUTH_TYPE"
        clientprinc="$CLIENT_PRINC"
        credentialcache="$CREDENTIAL_CACHE"
/>
EOF
	echo "[$INFO] ... the $AUTOFS_LDAP_AUTH_FILE file has been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  create new /etc/ssh/ssh_config function:
createSshConfig (){
    echo ">>> STEP 40 - $DATE_02 - BEGIN CONFIGURATION OF /ETC/SSH/SSH_CONFIG" | tee -a $LOG_FILE
    #  ...empty the current /etc/ssh/ssh_config file
    > $SSH_FILE
    #  ...create new /etc/ssh/ssh_config file
    cat <<EOF > $SSH_FILE
### THIS FILE CREATED BY THE DEVCENTER MAGICLAMP PROJECT ON $DATE ###
#       \$OpenBSD: ssh_config,v 1.21 2005/12/06 22:38:27 reyk Exp $

# This is the ssh client system-wide configuration file.  See
# ssh_config(5) for more information.  This file provides defaults for
# users, and the values can be changed in per-user configuration files
# or on the command line.

# Configuration data is parsed as follows:
#  1. command line options
#  2. user-specific file
#  3. system-wide file
# Any configuration value is only changed the first time it is set.
# Thus, host-specific definitions should be at the beginning of the
# configuration file, and defaults at the end.

# Site-wide defaults for some commonly used options.  For a comprehensive
# list of available options, their meanings and defaults, please see the
# ssh_config(5) man page.

$SSH_CONF_HOSTS
$SSH_CONF_FORWARD_AGENT
$SSH_CONF_FORWARD_X11
$SSH_CONF_RHOSTS_RSA_AUTHENTICATION
$SSH_CONF_RSA_AUTHENTICATION
$SSH_CONF_PASSWORD_AUTHENTICATION
$SSH_CONF_HOST_BASED_AUTHENTICATION
$SSH_CONF_BATCH_MODE
$SSH_CONF_CHECK_HOST_IP
$SSH_CONF_ADDRESS_FAMILY
$SSH_CONF_CONNECT_TIMEOUT
$SSH_CONF_STRICT_HOST_KEY_CHECKING
$SSH_CONF_IDENTITY_FILE_01
$SSH_CONF_IDENTITY_FILE_02
$SSH_CONF_IDENTITY_FILE_03
  $SSH_CONF_PORT
  $SSH_CONF_PROTOCOL
$SSH_CONF_CIPHER
$SSH_CONF_CIPHERS
$SSH_CONF_ESCAPE_CHAR
$SSH_CONF_TUNNEL
$SSH_CONF_TUNNEL_DEVICE
$SSH_CONF_PERMIT_LOCAL_COMMAND
  $SSH_CONF_GSSAPI_AUTHENTICATION
  $SSH_CONF_GSSAPI_DELEGATION
# If this option is set to yes then remote X11 clients will have full access
# to the original X11 display. As virtually no X11 client supports the untrusted
# mode correctly we set this to yes.
  $SSH_CONF_FORWARD_X11_TRUSTED
# Send locale-related environment variables
  $SSH_CONF_SEND_ENV_01
  $SSH_CONF_SEND_ENV_02
  $SSH_CONF_SEND_ENV_03
EOF
	echo "[$INFO] ... the $SSH_FILE file has been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  create new /etc/ssh/sshd_config file function:
createSshdConfig (){
    echo ">>> STEP 41 - $DATE_02 - BEGIN CONFIGURATION OF /ETC/SSH/SSHD_CONFIG" | tee -a $LOG_FILE
    #  ...empty the current /etc/ssh/sshd_config file
    > $SSHD_FILE
    #  ...create new /etc/ssh/sshd_config file
    cat <<EOF > $SSHD_FILE
### THIS FILE CREATED BY THE DEVCENTER MAGICLAMP PROJECT ON $DATE ###
#       $OpenBSD: sshd_config,v 1.73 2005/12/06 22:38:28 reyk Exp $

# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# This sshd was compiled with PATH=/usr/local/bin:/bin:/usr/bin"

# The strategy used for options in the default sshd_config shipped with"
# OpenSSH is to specify options with their default value where"
# possible, but leave them commented.  Uncommented options change a"
# default value."

$SSHD_CONF_PORT
$SSHD_CONF_PROTOCOL
$SSHD_CONF_ADDRESS_FAMILY
$SSHD_CONF_LISTEN_ADDRESS_IPV4
$SSHD_CONF_LISTEN_ADDRESS_IPV6

$SSHD_CONF_ALLOW_GROUPS
$SSHD_CONF_ALLOW_USERS
$SSHD_CONF_DENY_GROUPS
$SSHD_CONF_DENY_USERS

# HostKey for protocol version 1
$SSHD_CONF_HOSTKEY_PROTOCOL_1
# HostKeys for protocol version 2
$SSHD_CONF_HOSTKEY_PROTOCOL_2_RSA
$SSHD_CONF_HOSTKEY_PROTOCOL_2_DSA

# Lifetime and size of ephemeral version 1 server key
$SSHD_CONF_KEY_REGENERATION_INTERVAL
$SSHD_CONF_SERVER_KEY_BITS

# Logging
# obsoletes QuietMode and FascistLogging
$SSHD_CONF_SYSLOG_FACILITY
$SSHD_CONF_LOG_LEVEL

# Authentication:

$SSHD_CONF_LOGIN_GRACE_TIME
$SSHD_CONF_PERMIT_ROOT_LOGIN
$SSHD_CONF_STRICT_MODES
$SSHD_CONF_MAX_AUTH_TRIES

$SSHD_CONF_RSA_AUTHENTICATION
$SSHD_CONF_PUB_KEY_AUTHENTICATION
$SSHD_CONF_AUTHORIZED_KEYS_FILE

# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
$SSHD_CONF_RHOSTS_RSA_AUTHENTICATION
# similar for protocol version 2
$SSHD_CONF_HOST_BASED_AUTHENTICATION
# Change to yes if you don't trust ~/.ssh/known_hosts for
# RhostsRSAAuthentication and HostbasedAuthentication
$SSHD_CONF_IGNORE_USER_KNOWN_HOSTS
# Don't read the user's ~/.rhosts and ~/.shosts files
$SSHD_CONF_IGNORE_RHOSTS

# To disable tunneled clear text passwords, change to no here!
$SSHD_CONF_PERMIT_EMPTY_PASSWORDS
$SSHD_CONF_PASSWORD_AUTHENTICATION

# Change to no to disable s/key passwords
$SSHD_CONF_CHALLENGE_RESPONSE_AUTHENTICATION

# Kerberos options
$SSHD_CONF_KERBEROS_AUTHENTICATION
$SSHD_CONF_KERBEROS_OR_LOCAL_PASSWD
$SSHD_CONF_KERBEROS_TICKET_CLEANUP
$SSHD_CONF_KERBEROS_GET_AFS_TOKEN

# GSSAPI options
$SSHD_CONF_GSSAPI_AUTHENTICATION
$SSHD_CONF_GSSAPI_CLEANUP_CREDENTIALS

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the ChallengeResponseAuthentication mechanism.
# Depending on your PAM configuration, this may bypass the setting of
# PasswordAuthentication, PermitEmptyPasswords, and
# "PermitRootLogin without-password". If you just want the PAM account and
# session checks to run without PAM authentication, then enable this but set
# ChallengeResponseAuthentication=no
$SSHD_CONF_USE_PAM

# Accept locale-related environment variables
$SSHD_CONF_ACCEPT_ENV_01
$SSHD_CONF_ACCEPT_ENV_02
$SSHD_CONF_ACCEPT_ENV_03
$SSHD_CONF_ALLOW_TCP_FORWARDING
$SSHD_CONF_GATEWAY_PORTS
$SSHD_CONF_X11_FORWARDING
$SSHD_CONF_X11_DISPLAY_OFFSET
$SSHD_CONF_X11_USE_LOCAL_HOST
$SSHD_CONF_PRINT_MOTD
$SSHD_CONF_PRINT_LAST_LOG
$SSHD_CONF_TCP_KEEP_ALIVE
$SSHD_CONF_USE_LOGIN
$SSHD_CONF_USE_PRIVILEGE_SEPARATION
$SSHD_CONF_PERMIT_USER_ENVIRONMENT
$SSHD_CONF_COMPRESSION
$SSHD_CONF_CLIENT_ALIVE_INTERVAL
$SSHD_CONF_CLIENT_ALIVE_COUNT_MAX
$SSHD_CONF_SHOW_PATCH_LEVEL
$SSHD_CONF_USE_DNS
$SSHD_CONF_PID_FILE
$SSHD_CONF_MAX_STARTUPS
$SSHD_CONF_PERMIT_TUNNEL
$SSHD_CONF_CHROOT_DIRECTORY

# no default banner path
$SSHD_CONF_BANNER

# override default of no subsystems
$SSHD_CONF_SFTP_SUBSYSTEM
EOF
	echo "[$INFO] ... the $SSHD_FILE file has been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  stop and start the sshd service function:
restartSshdService (){
    echo ">>> STEP 42 - $DATE_02 - BEGIN RESTART OF SSHD SERVICE" | tee -a $LOG_FILE
    #  ...first stop it
    OUTPUT_01=$(ps aux | grep -v grep | grep $SSHD_SERVICE_NAME)
    if [ "${#OUTPUT_01}" -gt 0 ];
    then
        echo "[$PASS] ... the $SSHD_SERVICE service is running...stopping service." | tee -a $LOG_FILE && service $SSHD_SERVICE stop
    else
        echo "[$INFO] ... the $SSHD_SERVICE service is not running." | tee -a $LOG_FILE
    fi
    #  ...now start it
    OUTPUT_02=$(ps aux | grep -v grep | grep $SSHD_SERVICE_NAME)
    if [ "${#OUTPUT_02}" -lt 1 ];
    then
        echo "[$PASS] ... the $SSHD_SERVICE service is stopped...starting the service." | tee -a $LOG_FILE && service $SSHD_SERVICE start
    else
        echo "[$INFO] ... the $SSHD_SERVICE service is already running." | tee -a $LOG_FILE
    fi
    echo "" | tee -a $LOG_FILE
}

#  create new ssh login banner function:
createSshLoginBanner (){
    echo ">>> STEP 43 - $DATE_02 - BEGIN CREATE SSH LOGIN BANNER" | tee -a $LOG_FILE
    touch $BANNER_FILE
	#  ...clear out the existing $BANNER_FILE
	> $BANNER_FILE
    #  ...populate the $BANNER_FILE
    echo '*******************************************************************************' >> $BANNER_FILE
    echo '*******************************************************************************' >> $BANNER_FILE
    echo '**                                                                           **' >> $BANNER_FILE
    echo '** SECURITY NOTICE:                                                          **' >> $BANNER_FILE
    echo '**                                                                           **' >> $BANNER_FILE
    echo '** Only authorized users may use this system for legitimate business         **' >> $BANNER_FILE
    echo '** purposes. There is no expectation of privacy in connection with your      **' >> $BANNER_FILE
    echo '** activities or the information handled, sent, or stored on this network.   **' >> $BANNER_FILE
    echo '** By accessing this system you accept that your actions on this network may **' >> $BANNER_FILE
    echo '** be monitored and/or recorded.  Information gathered may be used to pursue **' >> $BANNER_FILE
    echo '** any and all remedies available by law, including termination of           **' >> $BANNER_FILE
    echo '** employment or the providing of the evidence of such monitoring to law     **' >> $BANNER_FILE
    echo '** enforcement officials.                                                    **' >> $BANNER_FILE
    echo '**                                                                           **' >> $BANNER_FILE
    echo '*******************************************************************************' >> $BANNER_FILE
    echo '*******************************************************************************' >> $BANNER_FILE
	echo "[$INFO]...the $BANNER_FILE file has been created." | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

#  create new /etc/motd file function:
createMotd (){
    echo ">>> STEP 44 - $DATE_02 - BEGIN CREATE /ETC/MOTD" | tee -a $LOG_FILE
    #  ...clear out the current /etc/motd file
    > $MOTD_FILE
        #  ...copy the contents of the /etc/ssh/$CORE_SSH_BANNER_FILE to /etc/motd 
    cat $BANNER_FILE > $MOTD_FILE
    echo "[$INFO] ... the $MOTD_FILE file has been created." | tee -a $LOG_FILE
    cat $MOTD_FILE
	echo "" | tee -a $LOG_FILE
}

### core logic

#  clear the screen ...
clear

#  check usage ...
[[ $# -eq 0 ]] && usage

#  source msktutil_core_core.conf ...
SOURCEDIR=/mnt/repository/lps/msktutil_core
if [ -f ${SOURCEDIR}/CORE_SCRIPTS/msktutil_core_core.conf ];
    then
        source ${SOURCEDIR}/CORE_SCRIPTS/msktutil_core_core.conf
fi
        
#  create log files ...
logFiles

cat <<EOF | tee -a $LOG_FILE
##################################################
#                                                #
#    WELCOME TO THE MSKTUTIL_CORE INSTALL!       #
#                                                #
##################################################

EOF

#  prompt for username ...
adUser

cat <<EOF | tee -a $LOG_FILE
##################################################
#                                                #
#    STARTING INITIAL SYSTEM CONFIGURATION ...   #
#                                                #
##################################################

EOF

#  see if server is running linux ...
isLinux

#  determine what version of rhel is being used ...
rhelVersion

#  determine what archictecture the server is using ...
whatArch

#  perform first backup of affected system files ...
firstBackup

#  check for and install epel repository key if required ...
epelKey

#  upload the k5start_ldap init script ...
uploadK5startLDAP

#  upload k5start_nfsv4 init script ...
#  this doesn't work in the way i intended ... removed.
#uploadK5startNFSv4

#  upload the krb5_ticket_renew.sh script ...
uploadKrb5TicketRenew

#  upload the krb5_ticket_renew.conf file ...
uploadKrb5TicketRenewConf

#  install core RPMs to resolve dependencies ...
coreRPMInstall

#  install kstart RPM ...
installKstart

#  install msktutil RPM ...
installMsktutil

#  install krb5-workstation RPM ...
installKrb5Workstation

#  install nss-ldap RPM ...
installNssLdap

#  install openldap RPM ...
installOpenLdap

#  install the openldap-clients RPM ...
installOpenLdapClients

#  stop winbind, turn service off, uninstall all samba3x RPMs ...
removeWinbind

#  update the etc/hosts file ...
updateHosts

#  create the /etc/resolv.conf file ...
configResolv

#  create the /etc/ntp.conf file and configure ntpd ...
configNtp

#  configure the HOSTNAME value in /etc/sysconfig/network ...
configNetwork

cat <<EOF | tee -a $LOG_FILE
##################################################
#                                                #
#   INITIAL KERBEROS CONFIGURATION COMPLETE ...  #
#                                                #
##################################################

EOF

cat <<EOF | tee -a $LOG_FILE
##################################################
#                                                #
#   STARTING LDAP AND KERBEROS 5 CONFIGURATION   #
#                                                #
##################################################

EOF

#  run authconfig ...
initAuthConfig

#  create /etc/nscd.conf file ...
createNscdConf

#  create the new /etc/krb5.conf file ...
createKrb5Conf

#  create the new /etc/pam.d/system-auth file function ...
createPamSystemAuth

#  create the new /etc/ldap.conf and /etc/openldap/ldap.conf files ...
createOpenLdapConf

#  create the new /etc/nsswitch.conf file ...
createNsswitchConf

#  create the new /etc/idmapd.conf file ...
createIdmapdConf

#  create the active directory nfsv4 service using msktutil ...
createADNFSv4Service

sleep 5

#  create the active directory computer objects using msktutil ...
createADComputerObject

sleep 5

#  create new /etc/sysconfig/nfs file ...
createSysconfigNfs

#  create new /etc/sysconfig/autofs file ...
createSysconfigAutofs

#  create msktutil ad change computer password crontab ...
#  not using this, setting computer objects to never expire
#createAdChangeComputerPasswordCron

echo ">>> [$WARN] STEP 33 is not being processed."
echo ""

#  create msktutil ad change nfsv4 service password crontab ...
#  not using this, setting computer objects to never expire
#createAdChangeNFSv4ServicePasswordCron

echo ">>> [$WARN] STEP 34 is not being processed."
echo ""

sleep 5

#  start the k5start_ldap service and set service run levels ...
startK5startLdap

#  start the k5start_ldap service and set service run levels function ...
#  this is not working as intended and probably not needed at all
#startK5startNfsv4

echo ">>> [$WARN] STEP 36 is not being processed."
echo ""

#  query ldap for user data...
queryAdUser

#  destroy the kerberos ticket acquire earlier for the active directory user ...
destroyKerberosTicket

#  configure the new /etc/autofs_ldap_auth.conf file ...
createAutoFSLdapAuthConf

cat <<EOF | tee -a $LOG_FILE
##################################################
#                                                #
#   LDAP AND KERBEROS 5 CONFIGURATION COMPLETE   #
#                                                #
##################################################

EOF

cat <<EOF | tee -a $LOG_FILE
##################################################
#                                                #
#            START SSH CONFIGURATION             #
#                                                #
##################################################

EOF

#  create new /etc/ssh/ssh_config ...
createSshConfig

#  create new /etc/ssh/sshd_config file ...
createSshdConfig

#  stop and start the sshd service ...
restartSshdService

#  create new ssh login banner ...
createSshLoginBanner

#  create new /etc/motd file ...
createMotd

cat <<EOF | tee -a $LOG_FILE
##################################################
#                                                #
#           SSH CONFIGURATION COMPLETE           #
#                                                #
##################################################

EOF

cat <<EOF | tee -a $LOG_FILE
##################################################
#                                                #
#     THE MSKTUTIL_CORE INSTALL IS COMPLETE!     #
#                                                #
##################################################

EOF

echo "[$INFO]...INSTALL FINISH TIME: $DATE_02" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "<<< END MSKTUTIL_CORE INSTALL >>>" >> $LOG_FILE

exit 0