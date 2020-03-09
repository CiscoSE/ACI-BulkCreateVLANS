# Copyright (c) 2020 Cisco and/or its affiliates.

# This software is licensed to you under the terms of the Cisco Sample
# Code License, Version 1.0 (the "License"). You may obtain a copy of the
# License at

#               https://developer.cisco.com/docs/licenses

# All use of the material herein must be in accordance with the terms of
# the License. All rights not expressly granted by the License are
# reserved. Unless required by applicable law or agreed to separately in
# writing, software distributed under the License is distributed on an "AS
# IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied.

# Items you should probably change - Configurable by Argument 
apicDefault='';             apic=''							# Can be a DNS name or IP depending on your environment
userNameDefault='';         userName=''					# User Name to Logon to the APIC
aepNameDefault=''           aepName=''	        # AEP Name for configuration

# Constants used through out the script
aepDnPrefix='uni/infra/attentp-'; aepDn=''

#Debug Variables
writeLogFile="./$(date +%Y%m%d-%H%M%S)-xmlLogFile.log"	#Time stamped file name.
writeLog='enabled'					#When enabled, XML is logged to the file system along with any status messages. 
#writeLog='disabled'


argumentExit(){
  # Required for help processing
  printf '%s\n' "$1" >&2
	exit 1
}

#Help File
showHelp() {
  cat << EOF
  Usage: ${0##*/} [--apic [IP]] [--user [User]] [--aepName [DN]] --interfaceName [Name] [--start [Num]] [--last [Num]]...

  Where:

      -h               Display this help and exit
      --apic           IP or fqdn of APIC to be changed
      --user           Username to access APIC
      -v               verbose mode. 
EOF
}


#Color Coding for screen output.
green="\e[1;32m"
red="\e[1;31m"
yellow="\e[1;33m"
normal="\e[1;0m"


function exitRoutine () {
  #Use this instead of the exit command to ensure we clean up the cookies.
  if [ -f cookie.txt ]; then
    rm -f cookie.txt
    printf "%5s[ ${green} INFO ${normal} ] Removing APIC cookie\n"
  fi
  exit
}

function accessAPIC () {
  XMLResult=''
  errorReturn=''
  XMLResult=$(curl -b cookie.txt -skX ${1} ${2} -d "${3}"  --header "content-type: appliation/xml, accept: application/xml" )
  errorCode=$(echo $XMLResult | grep -oE "error code=\".*"  | sed "s/error code=\"//" | sed "s/\".*//")
  errorText=$(echo $XMLResult | grep -oE "text=\".*"  | sed "s/text=\"//" | sed "s/\".*//")
  if [ "$errorCode" != '' ]; then
    writeStatus "APIC Call Failed.\nError Code: ${errorCode}\nXML Result: ${XMLResult}\nType: ${1}\nURL: ${2}\nXML: \n${3}" 'FAIL'
  fi
  #used only for debuging
  if [ "${4}" = 'TRUE' ]; then
	printf "Type: ${1}"
	printf "URL: ${2}"
	printf "XML Sent:\n${3}\n\n"
	printf "XML Result:\n${XMLResult}\n\n"
	exitRoutine
  fi
  if [ "${writeLog}" = 'enabled' ]; then
    	printf "Type: ${1}" >> $writeLogFile
	printf "URL: ${2}" >> $writeLogFile		
	printf "XML Sent:\n${3}\n\n" >> $writeLogFile
	printf "XML Result:\n${XMLResult}\n\n" >> $writeLogFile
  fi

}

function getCookie () {
	#Remove a cookie if it exists
	rm -f cookie.txt
	echo -n Enter the password for the APIC.
	read -s password
	cookieResult=$(curl -sk https://${apic}/api/aaaLogin.xml -d "<aaaUser name='${userName}' pwd='${password}'/>" -c cookie.txt)
	printf "\n"
	writeStatus "%5s Cookie Obtained - Access to APIC established"
}

function writeStatus (){	
  if [ "${2}" = "FAIL" ]; then 
    printf "%5s[ ${red} FAIL ${normal} ] ${1}\n"
    # Begin Exit Reroutine
    exitRoutine
  fi
  
  printf "%5s[ ${green} INFO ${normal} ] ${1}\n"

  if [ "${writeLog}" = 'enabled' ]; then
    printf "%5s[ ${green} INFO ${normal} ] ${1}\n" >> $writeLogFile
  fi
}

#Log File Start
if [ "${writeLog}" = 'enabled' ]; then
  printf 'Starting Log file' > $writeLogFile
fi

while :; do
  case $1 in 
    -h|-\?|--help)
		  showHelp			# Display help in formation in showHelp
			exit
		  ;;
		--apic)
		  if [ "$2" ]; then
			  apic=$2
				shift
			fi
		  ;;
		--user)
		  if [ "$2" ]; then
			  userName=$2
				shift
			fi
			;;
		-v|--verbose)
		  verbose=$((verbose + 1))
		  ;;
		*)
		  break
  esac
	shift
done

#Set defaults if the value isnt set by argument. 
if [[ ( -z ${apic} && -n ${apicDefault} ) ]]; then
  apic=$apicDefault
elif [[ -z ${apic} ]]; then
  writeStatus "Required value (APIC) not present" 'FAIL'
fi

if [[ ( -z ${userName} && -n ${userNameDefault} ) ]]; then
  userName=$userNameDefault
elif [[ -z ${userName} ]]; then
  writeStatus "Required value (user) not present" 'FAIL'
fi

writeStatus "APIC Value: \t\t${apic}"
writeStatus "userName Value: \t${userName}"
writeStatus "verbose Value:\t\t${verbose}"

#Get cookie

getCookie

#TODO Use this for access.
#accessAPIC 'POST' "https://${apic}/api/node/mo/uni/infra/funcprof.xml" "${breakoutPolicyXML}"


#Removing the cookie used for access to the APIC
exitRoutine


