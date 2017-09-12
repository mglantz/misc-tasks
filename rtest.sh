#!/bin/bash
#
#    Written by: Magnus Glantz ( open.grieves@gmail.com )
#    Copyright 2011
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


help(){
	echo "$0 [-l|-c|-h|NAME_OF_RPM][-v]"
	echo "-l	List RPMs that is currently running active processes"
	echo "-v	Verbose. List RPMs that is matched."
	echo "-c	Check impact of RPMs available via yum check-update"
	echo "-h	Help."
	exit 0
}

RUNNING_WITH_PATH=$(ps -ef|awk '{ print $8 }'|fgrep -v [|sort|uniq|fgrep /)
RUNNING_WITOUT_PATH=$(which $(ps -ef|awk '{ print $8 }'|fgrep -v [|sort|uniq|fgrep -v /|sed 's/://') 2>/dev/null)
ALL_RUNNING_PATHS=$(echo $RUNNING_WITH_PATH $RUNNING_WITHOUT_PATH|sort|uniq)
ACTIVE_LIBS=$(lsof|awk '{ print $9 }'|fgrep /|sort|uniq|grep [a-z]|sort|uniq 2>/dev/null)

#REBOOTPKGS=(kernel kernel-smp glibc hal dbus kernel-xen-hypervisor kernel-PAE libvirt)

if [ -f /tmp/tmp.running.with.rpm.owner ]; then
        rm -f /tmp/tmp.running.with.rpm.owner
fi

if [ -f /tmp/rpm.match.runs ]; then
	rm -f /tmp/rpm.match.runs
fi

if [ -f /tmp/tmp.lib.with.rpm.owner ]; then
	rm -f /tmp/tmp.lib.with.rpm.owner
fi

if [ -f /tmp/tmp.rpm.match ]; then
	rm -f /tmp/tmp.rpm.match
fi

for APATH in ${ALL_RUNNING_PATHS[@]}; do
	rpm -qf $APATH >/dev/null 2>&1
	if [ "$?" -eq 0 ]; then
		echo $APATH >>/tmp/tmp.running.with.rpm.owner
	fi
done

for LPATH in ${ACTIVE_LIBS[@]}; do
	rpm -qf $LPATH >/dev/null 2>&1
	if [ "$?" -eq 0 ]; then
		echo $LPATH >>/tmp/tmp.lib.with.rpm.owner
	fi
done

ALL_RUNNING_WITH_RPM_OWNERS=$(rpm -qf $(cat /tmp/tmp.running.with.rpm.owner)|sort|uniq)
ALL_LIBS_WITH_RPM_OWNERS=$(rpm -qf $(cat /tmp/tmp.lib.with.rpm.owner)|sort|uniq)

VERBOSE=0

if [ "$1" == "-c" ]; then
	CHECK=$(yum check-update|awk '{ print $1 }'|grep "[a-z]\."|sed 's/\.\(.*\)//')
	for ARG in ${CHECK[@]}; do
		for ITEM in ${ALL_RUNNING_WITH_RPM_OWNERS[@]}; do
			echo $ITEM|grep "$ARG-[0-9]" >>/tmp/rpm.match.runs
		done
	done
        for ARG in ${CHECK[@]}; do
                for ITEM in ${ALL_LIBS_WITH_RPM_OWNERS[@]}; do
                        echo $ITEM|grep "$ARG-[0-9]" >>/tmp/rpm.match.runs
                done
        done
	for ARG in "$@"; do
		if [ "$ARG"  == "-v" ]; then
			echo "Searched for matches for the following RPMs:"
			for ARG in ${CHECK[@]}; do
                        	echo $ARG
                	done
			echo
		fi
	done
elif [ "$1" == "" ]; then
	help
else	
	for ARG in "$@"; do
		if [ "$ARG" == "-l" ]; then
			echo "RPMs owning running processes:"
			for ARPM in ${ALL_RUNNING_WITH_RPM_OWNERS[@]}; do
				echo $ARPM
			done
			echo
			echo "RPMs owning in-use libraries:"
			for LRPM in ${ALL_LIBS_WITH_RPM_OWNERS[@]}; do
				echo $LRPM
			done
			exit 0
		elif [ "$ARG" == "-v" ]; then
			VERBOSE=1
		elif [ "$ARG" == "-h" ]; then
			help
		else
			for ITEM in ${ALL_RUNNING_WITH_RPM_OWNERS[@]}; do
				echo $ITEM|grep "$ARG-[0-9]" >>/tmp/rpm.match.runs
			done
                        for ITEM in ${ALL_LIBS_WITH_RPM_OWNERS[@]}; do
                                echo $ITEM|grep "$ARG-[0-9]" >>/tmp/rpm.match.runs
                        done
		fi
	done
fi

cat /tmp/rpm.match.runs|sort|uniq >/tmp/tmp.rpm.match

ALL_AFFECTED=$(cat /tmp/tmp.rpm.match)
NR_AFFECTED=$(cat /tmp/tmp.rpm.match|wc -l)

if [ "$NR_AFFECTED" -ne "0" ]; then
	echo "WARNING: Detected $NR_AFFECTED RPM(s) that owns running processes or used libraries"
	if [ $VERBOSE -eq 1 ]; then
        	cat /tmp/rpm.match.runs
	fi
	exit 2
else
	echo "OK: The RPM(s) does not own any running processes or used libraries."
	exit 0
fi
