#!/bin/sh

# disable history characters
histchars=

SCRIPT_NAME=`basename "${0}"`

echo "${SCRIPT_NAME} - v1.18 ("`date`")"

# Usage: ${SCRIPT_NAME} $1 $2 $3
# $1 -> realname
# $2 -> shortname
# $3 -> password

USER_REALNAME=${1}
USER_SHORTNAME=${2}
USER_PASSWORD=${3}
USER_UID=${4}
USER_ADMIN="YES"
USER_HIDDEN=
USER_LOCALE=
USER_EXISTS=`dscl /Local/Default -list /Users | grep ${USER_SHORTNAME}`

# USER_NETWORK_HOME=`dscl /Local/Default -read /Users/${2} OriginalNFSHomeDirectory | awk '{ print $2 }'`

if [ -z "${USER_REALNAME}" ] || [ -z "${USER_SHORTNAME}" ] || [ -z "${USER_PASSWORD}" ]
then
  echo "Usage: ${SCRIPT_NAME} \"full name\" username password [uid]"
  exit 1
fi

USER_HOME="/Users/${USER_SHORTNAME}"
if [ -n "${USER_EXISTS}" ]
then
  USER_HOME=`dscl /Local/Default -read /Users/${2} home | awk '{ print $2 }'`
  if [ -z "${USER_UID}" ] 
  then
    USER_UID=`dscl /Local/Default -read /Users/${2} uid | awk '{ print $2 }'`
    if [ -z "${USER_UID}" ]
    then
      echo "  No uid for user '${USER_SHORTNAME}' - aborting" 2>&1
      exit 1
    fi
  fi
fi

if [ -z "${USER_UID}" ]
then
  USER_UID=`dscl /Local/Default -list /Users uid | awk '{ print $2 }' | sort -n | tail -n 1`
  USER_UID=`expr ${USER_UID} + 1`
  if [ ${USER_UID} -lt 501 ]
  then
    USER_UID=501
  fi
  echo "  No uid specified for new account ${USER_SHORTNAME}, using next available (${USER_UID})" 2>&1
fi

# 
# destroy the existing (mobile) user
#

if [ -n "${USER_EXISTS}" ]
then
  echo "  Removing user '${USER_SHORTNAME}'" 2>&1
  dscl -plist /Local/Default -read /Users/${USER_SHORTNAME} > "${USER_SHORTNAME}.plist"
  dscl /Local/Default -delete users/${USER_SHORTNAME} >/dev/null 2>&1
fi

#
# create the user
#

echo "  Creating user '${USER_SHORTNAME}' with uid ${USER_UID} and home directory ${USER_HOME}" 2>&1

dscl /Local/Default -create users/${USER_SHORTNAME}

dscl /Local/Default -create users/${USER_SHORTNAME} uid           "${USER_UID}"
dscl /Local/Default -create users/${USER_SHORTNAME} gid           20
dscl /Local/Default -create users/${USER_SHORTNAME} GeneratedUID  `/usr/bin/uuidgen`
dscl /Local/Default -create users/${USER_SHORTNAME} home          "${USER_HOME}"
dscl /Local/Default -create users/${USER_SHORTNAME} shell         "/bin/bash"

dscl /Local/Default -create users/${USER_SHORTNAME} _writers_UserCertificate "${USER_SHORTNAME}"
dscl /Local/Default -create users/${USER_SHORTNAME} _writers_hint            "${USER_SHORTNAME}"
dscl /Local/Default -create users/${USER_SHORTNAME} _writers_jpegphoto       "${USER_SHORTNAME}"
dscl /Local/Default -create users/${USER_SHORTNAME} _writers_passwd          "${USER_SHORTNAME}"
dscl /Local/Default -create users/${USER_SHORTNAME} _writers_picture         "${USER_SHORTNAME}"
dscl /Local/Default -create users/${USER_SHORTNAME} _writers_realname        "${USER_SHORTNAME}"

if [ -e "/Library/User Pictures/Fun/Gingerbread Man.tif" ]
then
  dscl /Local/Default -create users/${USER_SHORTNAME} picture "/Library/User Pictures/Fun/Gingerbread Man.tif"
else
  if [ -e "/Library/User Pictures/Animals/Butterfly.tif" ]
  then
    dscl /Local/Default -create users/${USER_SHORTNAME} picture "/Library/User Pictures/Animals/Butterfly.tif"
  fi
fi

if [ -n "${USER_REALNAME}" ]
then 
  dscl /Local/Default -create users/${USER_SHORTNAME} realname "${USER_REALNAME}"
else
  dscl /Local/Default -create users/${USER_SHORTNAME} realname "${USER_SHORTNAME}"
fi

if [ -n "${USER_PASSWORD}" ]
then 
  dscl /Local/Default -passwd /Users/${USER_SHORTNAME} "${USER_PASSWORD}"
else
  dscl /Local/Default -passwd /Users/${USER_SHORTNAME} ""
fi  

if [ "_YES" = "_${USER_ADMIN}" ]
then 
echo "  Setting admin properties" 2>&1
  dscl /Local/Default -merge  groups/admin            users   "${USER_SHORTNAME}"
  # Enable all ARD privileges
  dscl /Local/Default -create users/${USER_SHORTNAME} naprivs -1073741569
fi

if [ -d "${USER_HOME}" ] 
then
  echo "  Setting ownership on local home directory ${USER_HOME}" 2>&1
else
  HOMES_ROOT=`dirname "${USER_HOME}"`
  if [ -d  "${HOMES_ROOT}" ] && [ -d "/System/Library/User Template" ]
  then
    echo "  Creating local home directory ${USER_HOME} from template" 2>&1
    if [ -d "/System/Library/User Template/${USER_LOCALE}.lproj" ]
    then
     ditto --rsrc "/System/Library/User Template/${USER_LOCALE}.lproj" "${USER_HOME}"
    else
     ditto --rsrc "/System/Library/User Template/English.lproj" "${USER_HOME}"
    fi
  fi
fi
chown -R ${USER_UID}:20 "${USER_HOME}"

if [ "_YES" == "_${USER_HIDDEN}" ]
then
  defaults write /Library/Preferences/com.apple.loginwindow HiddenUsersList -array-add "${USER_SHORTNAME}"
  chmod 644 /Library/Preferences/com.apple.loginwindow.plist
  chown root:admin /Library/Preferences/com.apple.loginwindow.plist
fi
