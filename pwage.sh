#!/bin/bash

#PROGPATH=`echo $0 | /bin/sed -e 's,[\\/][^\\/][^\\/]*$,,'`

#LIBEXEC="/opt/nagios/libexec"
#. $LIBEXEC/utils.sh

# Default values (days):
critical=3
warning=10

# Parse arguments
args=`getopt -o hu:w:c: --long help,user:,warning:,critical:,path: -u -n $0 -- "$@"`
[ $? != 0 ] && echo "$0: Could not parse arguments" && echo "Usage: $0 -h | -u <user> [-c <critical>] [-w <warning>]" && exit
set -- $args

while true ; do
    case "$1" in
        -c|--critical) critical=$2;shift 2;;
        -w|--warning)  warning=$2;shift 2;;
        -u|--user)   user=$2;shift 2;;
        -h|--help)     echo "$0 - v1.00"
           echo "This plugin checks the expiration date user password."
           echo ""
           echo "Usage: $0 -h | -u <user> [-c <critical>] [-w <warning>]"
           echo "NOTE: -u must be specified"
           echo ""
           echo "Options:"
           echo "-h"
           echo "     Print detailed help"
           echo "-u"
           echo "     User name to check"
           echo "-w"
           echo "     Days to result in warning status"
           echo "-c"
           echo "     Days to result in critical status"
           echo ""
           echo "This plugin will read /etc/shadow to get the expiration date for the user name. "
           echo "Example:"
           echo "     $0 -u username -w 10 -c 3"
           echo ""
           exit;;
        --) shift; break;;
        *)  echo "Internal error!" ; exit 1 ;;
    esac
done

[ -z $user ] && echo "UNKNOWN - There is no user to check" && exit $STATE_UNKNOWN

CHKUSER=`grep ^$user /etc/passwd | cut -d: -f1`
if [ "$CHKUSER" = "$user" ]; then
	:
else
   echo "UNKNOWN - There is no user in password file" && \
   exit $STATE_UNKNOWN
fi
# Calculate days until expiration
CURRENT_EPOCH=`grep $user /etc/shadow | cut -d: -f3`
if [ "$CURRENT_EPOCH" = "" ]; then
   echo "UNKNOWN - There is no last password change to check" && \
   exit $STATE_UNKNOWN
fi
# Find the epoch time since the user's password was last changed
EPOCH=`perl -e 'print int(time/(60*60*24))'`
# Compute the age of the user's password
AGE=`echo $EPOCH - $CURRENT_EPOCH | bc`
# Compute and display the number of days until password expiration
MAX=`grep $USER /etc/shadow | cut -d: -f5`
##################################################################
mydate="`date +%s`"
mydate=`chage -l $user | grep "Password expires" | cut -f2 -d':'`
if [ "$mydate" == " never" ];then
 echo "OK - User's password will not expire"; exit 0;
fi

datum2=`date -d "$mydate" "+%s"`
datum1=`date "+%s"`
diff=$(($datum2-$datum1))
days=$(($diff/(60*60*24)))

expdays=$days
#################################################################
# Trigger alarms if applicable
[ -z "$expdays" ] && echo "UNKNOWN - User doesn't exist." && exit $STATE_UNKNOWN
[ $expdays -lt 0 ] && echo "CRITICAL - User's password expired on $EPOCH" && exit $STATE_CRITICAL
[ $expdays -lt $critical ] && echo "CRITICAL - User's password will expire in $expdays days" && exit $STATE_CRITICAL
[ $expdays -lt $warning ]&& echo "WARNING - User's password will expire in $expdays days" && exit $STATE_WARNING

# No alarms? Ok, everything is right.
echo "OK - User's password will expire in $expdays days"
exit $STATE_OK
