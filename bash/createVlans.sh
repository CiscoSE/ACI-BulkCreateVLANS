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

#You have to change this. No array handling was implemented as part of arguments 
VLANs=(1 2 4)

# Items you should probably change - Configurable by Argument 
apicDefault='';             apic=''					    # Can be a DNS name or IP depending on your environment
userNameDefault='';         userName=''					# User Name to Logon to the APIC
epgPrefixDefault='';        epgPrefix=''				# We use this as a naming prefix
BDPrefixDefault='';			BDPrefix=''					# Used as Bridge Domain prefix
vrfNameDefault='';			vrfName=''					# We need to know what vrf to build the bridge domain to.
tenantNameDefault='';       tenantName=''				# Tenant to create epgs and Bridge Domains in.

#These are defaults for the bridge domain. You can change them, but you should understand them before you do.

arpFlood='yes'			#Only other option is no
epMoveDetectMode='garp' #Helps when ACI detects VM traffic moving between switches.
ipLearning='yes'		#Allows for finding end points by IP address in ACI
limitIpLearnToSubnets="no" #We will learn the IP even if it is not on the right subnet. 
unkMacUcastAct="flood"  # Flood for unknown unicast. 


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
	  --epgPrefix	   Prefix used for EPG Names
	  --BDPrefix	   Prefix used for BD Names
	  --vrfName		   vrf bridge domains should use
	  --TenantName	   Name of Tenant for EGPs and BDs
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
	printf "\nType: ${1}"
	printf "\nURL: ${2}"
	printf "\nXML Sent:\n${3}\n\n"
	printf "\nXML Result:\n${XMLResult}\n\n"
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

function validateVLANs (){
  #All values of VLANs must be integers because we use them for as the VLAN number and as part of the epg/BD names
  for vlan in ${VLANs[@]};
  do
    if (( $vlan > 0 && $vlan <3967  )); then
		writeStatus "VLAN ${vlan} is verified"
	else
		writeStatus "Entry ${vlan} is not an integer and will not work for this script." 'FAIL'
    fi
  done
}

function createBridgeDomain (){
  writeStatus "\tCreating Bridge Domain ${BDPrefix}${vlan}"
  read -r -d '' bridgeDomainTemplate << EOV
    <fvBD name="${BDPrefix}${vlan}" arpFlood="${arpFlood}" epClear="no" epMoveDetectMode="${epMoveDetectMode}" ipLearning="${ipLearning}" limitIpLearnToSubnets="${limitIpLearnToSubnets}" unkMacUcastAct="${unkMacUcastAct}" >
    <fvRsCtx tnFvCtxName="${vrfName}" />     
    </fvBD>
EOV
  accessAPIC 'POST' "https://${apic}/api/node/mo/uni/tn-${tenantName}.xml" "${bridgeDomainTemplate}"
}


function main (){
  #Loop through VLANs
  for vlan in ${VLANs[@]}; do
    writeStatus "Processing VLAN ${vlan}"
    #Create Bridge Domain
    createBridgeDomain
  done

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
		--epgPrefix)
		  if [ "$2" ]; then
			  epgPrefix=$2
			    shift
          fi
		  ;;
		--BDPrefix)
		  if [ "$2" ]; then
		      BDPrefix=$2
			  	shift
		  fi
		  ;;
        --vrfName)
		  if [ "$2" ]; then
		      vrfName=$2
			    shift
          fi
		  ;;
		--tenantName)
		  if [ "$2" ]; then
		      tenantName=$2
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
  writeStatus "Required value (apic) not present" 'FAIL'
fi

if [[ ( -z ${userName} && -n ${userNameDefault} ) ]]; then
  userName=$userNameDefault
elif [[ -z ${userName} ]]; then
  writeStatus "Required value (user) not present" 'FAIL'
fi

if [[ ( -z ${egpPrefix} && -n ${epgPrefixDefault} ) ]]; then
  epgPrefix=$epgPrefixDefault
elif [[ -z ${epgPrefix} ]]; then
  writeStatus "Required value (epgPrefix) not present" 'FAIL'
fi

if [[ ( -z ${BDPrefix} && -n ${BDPrefixDefault} ) ]]; then
  BDPrefix=$BDPrefixDefault
elif [[ -z ${BDPrefix} ]]; then
  writeStatus "Required value (BDPrefix) not present" 'FAIL'
fi

if [[ ( -z ${vrfName} && -n ${vrfNameDefault} ) ]]; then
  vrfName=$vrfNameDefault
elif [[ -z ${vrfName} ]]; then
  writeStatus "Required value (vrfName) not present" 'FAIL'
fi

if [[ ( -z ${TenantName} && -n ${tenantNameDefault} ) ]]; then
  tenantName=$tenantNameDefault
elif [[ -z ${tenantName} ]]; then
  writeStatus "Required value (tenantName) not present" 'FAIL'
fi


writeStatus "APIC Value: \t\t${apic}"
writeStatus "userName Value: \t${userName}"
writeStatus "verbose Value:\t\t${verbose}"
writeStatus "epgPrefix Value: \t${epgPrefix}"
writeStatus "BDPrefix Value: \t${BDPrefix}"
writeStatus "BDPrefix Value: \t${vrfName}"
writeStatus "tenantName Value: \t ${tenantName}"
#Get cookie

validateVLANs
getCookie
main
#TODO Use this for access.
#accessAPIC 'POST' "https://${apic}/api/node/mo/uni/infra/funcprof.xml" "${breakoutPolicyXML}"
#TODO VLAN List format.
#TODO Cycle through VLAN list
#TODO Create bridge domain and EPG based on template. 

#Removing the cookie used for access to the APIC
exitRoutine


