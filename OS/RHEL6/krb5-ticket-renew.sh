#! /bin/sh

# dipeit@gmail.com / 2010-09-01
# This script renews kerberos tickets for all logged on users
# that have not yet expired and removes tickets that have expired.
# It also allows a user to refresh her ticket in time by not 
# auto renewing tickets that have between 8 and 1 hour to live
# durning the last 4 days of the renew_lifetime. Thus, the user
# is not prompted for a password for 3 days after logon if the 
# ticket renew lifetime is 7 days (MS AD default policy)
# The user should set this env variable (6 hours):
# export PROMPT_COMMAND="k5start -H 360"
#
# Finally the scripts logs out users for who renew_lifetime is 
# less than 1 hour. (FORCELOGOUT is set to "no" by default) and
# sends a warning email to all users for who renew_lifetime is less than 
# 2 hours (SENDWARNING is set to "no" by default) 
# 
# Test cases, there are more test cases in the code below.
# kinit -l 10m -r 3d 
# (ticket_lifetime = 10 minutes,  renew_lifetime = 3 days)
#
# Please put this script in /etc/cron.hourly and edit /etc/krb5.conf :
##[libdefaults]
##    ticket_lifetime = 10h
##    renew_lifetime = 7d

# Set path to Kerberos binaries for RHEL
PATH=$PATH:/usr/kerberos/bin

if [ -f /etc/krb5-ticket-renew.conf ]; then
  . /etc/krb5-ticket-renew.conf
else
  SENDWARNING="no"
  FORCELOGOUT="no"
  MAILHOST="mx"
  HOURSTOEXPIRE=48
fi
DOMAIN=`hostname -d`
CURRUSERS=`users | sed 's/ /\n/g' | sort -u`
for TCACHE in $( ls -1 /tmp/krb5cc* 2> /dev/null ); do
    OWNER=$( ls -l $TCACHE | awk '{print $3}' )
    GROUP=$( ls -l $TCACHE | awk '{print $4}' )
    NOW=$( date +%s )
    EXPIRE_TIME=$( date -d "$( klist -c $TCACHE | grep -m1 krbtgt | awk '{print $3, $4}' )" +%s )
    RENEW_TIME=$( date -d "$( klist -c $TCACHE | grep -m1 "renew until" | awk '{print $3, $4}' )" +%s )

    #logger -i -t krb5-renew owner:$OWNER tcache:$TCACHE expire:$EXPIRE_TIME renew:$RENEW_TIME current:$NOW

    # If the ticket has already expired, might as well delete it
    # testcase: kinit -l 10s
    if [ $NOW -ge $EXPIRE_TIME ]; then
        kdestroy -c $TCACHE &> /dev/null:
        logger -i -t krb5-renew "Removed expired ticket cache for $OWNER: $TCACHE"

    # log user out if we are within one hour or less of max renew_lifetime, prevent lockup
    # testcase: kinit -l 1h -r 1h
    elif [ $( expr $RENEW_TIME - $NOW ) -le 3600 ]; then
        logger -i -t krb5-renew "time to log user $OWNER out!"
        if [[ $FORCELOGOUT == "yes" ]]; then
            kill -15 $(ps -U $OWNER -o "pid=")
            logger -i -t krb5-renew "send notice to user $OWNER !"
            emailbody=`mktemp`
            mail -s "You have been logged out from '`hostname`' and all your jobs have been ended." -r root@`hostname -f` \
                     -S "smtp=$MAILHOST.$DOMAIN" $OWNER@$DOMAIN < $emailbody
            rm $emailbody
        fi

    # notify user if we are between 3 and 4 hours of max renew_lifetime to prevent forced logout
    # testcase: kinit -l 1h -r 4h
    elif [ $( expr $RENEW_TIME - $NOW ) -le 14400 ]; then
        if [ $( expr $RENEW_TIME - $NOW ) -gt 10800 ]; then
            logger -i -t krb5-renew "send warning to user $OWNER that they are pending automated logout!"
            if [[ $SENDWARNING == "yes" ]]; then
                emailbody=`mktemp`
                echo "$OWNER, please make sure to login to '`hostname`' to update your credentials."  >> $emailbody
                echo "If you can't login within 3 hours you will be logged out and your running jobs will be ended." >> $emailbody
                mail -s "Please login to '`hostname`' within the next 3 hours." -r root@`hostname -f` \
                         -S "smtp=$MAILHOST.$DOMAIN" $OWNER@$DOMAIN < $emailbody
                rm $emailbody
            fi
        fi

    else

        # standard refresh loop, tickets are not in immediate danger to expire
        for user in $CURRUSERS; do
            if [[ $user == $OWNER ]]; then
                logger -i -t krb5-renew "user $OWNER is logged on, check renewal!"
                # renew ticket if it will expire in one hour or less 
                # testcase: kinit -l 1h -r 1d
                if [ $( expr $EXPIRE_TIME - $NOW ) -le 3600 ]; then
                    kinit -R -c $TCACHE
                    chown $OWNER:$GROUP $TCACHE
                    logger -i -t krb5-renew "auto renewed - 1h left - $OWNER - $TCACHE"

                # renew ticket if it will expire in 8 hours or less
                # testcase: kinit -l 8h -r 97h
                elif [ $( expr $EXPIRE_TIME - $NOW ) -le 28800 ]; then
                    # ....and if there is at least 96 hours left for renewal
                    let "SECTOEXPIRE = $HOURSTOEXPIRE * 3600"
                    if [ $( expr $RENEW_TIME - $NOW ) -ge $SECTOEXPIRE ]; then
                        kinit -R -c $TCACHE
                        chown $OWNER:$GROUP $TCACHE
                        logger -i -t krb5-renew "auto renewed < $HOURSTOEXPIRE h left: $OWNER - $TCACHE"
                    else
                        #testcase: kinit -l 8h -r 96h
                        logger -i -t krb5-renew "time for ticket refresh for $OWNER via k5start or systray app" 
                    fi
                fi
            fi
        done

    fi

done