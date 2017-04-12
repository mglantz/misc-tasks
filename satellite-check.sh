#!/bin/bash
# Sloppy Satellite 6.2 prereq checks
# Magnus Glantz, sudo@redhat.com, 2017

if [ "$(whoami)" != "root" ]; then
	echo "You need to be root to run this script."
else
	rpm -q nmap-ncat >/dev/null
	if [ "$?" -eq 0 ]; then
		break
	else
		yum -y install nmap-ncat -y
	fi
fi

if echo $1|grep -i help >/dev/null; then
	echo "Usage ($0):"
	echo "To do general testing of prereqs, just run: $0."
	echo "To test port openings:"
	echo "To test Client -> Satellite communication, run:"
	echo "* On the Satellite server: $0 satellite"
	echo "* On a RHEL server on a client network: $0 client <hostname-of-satellite>"
	echo "To test Capsule -> Satellite communication, run:"
	echo "* On the Satellite server: $0 satellite"
	echo "* On a RHEL server on a client network: $0 client <hostname-of-satellite>"
	echo "To test Satellite -> Capsule communication, run:"
	echo "* On the Capsule server: $0 capsule"
	echo "* On the Satellite server: $0 satellite-client <hostname-of-capsule>"
	exit 0
fi

if echo $1|grep -i satellite-client >/dev/null; then
        for item in 80 443 9090; do
                echo "Running check of port $item on server $2:"
                nc -z $2 $item
        done
        exit 0
fi

if echo $1|grep -i client >/dev/null; then
        for item in 80 443 5646 5647 8000 8140 8443 9090 5000; do
                echo "Running check of port $item on server $2:"
                nc -z $2 $item
        done
        exit 0
fi

if echo $1|grep -i satellite >/dev/null; then
	for item in 80 443 5646 5647 8000 8140 8443 9090 5000; do
        	echo "Initiating listener on port: $item. It will terminate once there is a successful connection to it, do not exit this shell session before running test."
        	nc -l $item &
	done
	exit 0
fi

if echo $1|grep -i capsule >/dev/null; then
        for item in 80 443 9090; do
                echo "Initiating listener on port: $item. It will terminate once there is a successful connection to it, do not exit this shell session before running test."
                nc -l $item &
        done
	exit 0
fi

echo "Needed free space is 1 TB of disk. We have $(pvs|grep [1-9]|awk '{ print $6 }')"
echo "System needs to be properly subscribed via subscription-manager. Subscription status to Satellite channel is: $(subscription-manager list|grep "Red Hat Satellite" -A4|grep "Status:         Subscribed")"
mount|egrep -v '(sys|tmpfs|devpts|devtmp|proc|hugetlb|mqueue)' >all
if grep -v xfs all|grep [a-z] >/dev/null ; then
	echo "Warning: Found filesystems which are not XFS:"
	grep -v xfs all
else
	echo "All filesystems are running XFS."
fi
if grep "Red Hat Enterprise Linux Server release 7.3" /etc/redhat-release >/dev/null; then
	echo "OK: We are running RHEL 7.3"
else
	echo "Warning: We are running $(cat /etc/redhat-release)"
fi
