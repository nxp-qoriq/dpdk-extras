#/*
# * Copyright (c) 2015-2016 Freescale Semiconductor, Inc. All rights reserved.
# */

help() {
	echo
	echo "USAGE: . ./loopback_sanity_test.sh <options>
The Options are:
	-a		Auto mode		Enabling the Auto mode. Default is manual
						mode.

	-p=\"num\"	Ping packets numbers	'num' is number of ping packets which will be used
						for sanity testing. Default is 10.

	-d		Developer help		This option is only for developers. It will
						print the help for developers, which describes
						how to add a test case in the script.

	-h		Help			Prints script help.

Example:
	. ./loopback_sanity_test.sh -a        OR     source ./loopback_sanity_test.sh -a

Options and Sanity script running behaviour:

	OPTIONS					SCRIPT BEHAVIOUR

	* Both -a and -c			If both options -a and -c are given, then script will
						run all the test cases automatically including Cunit
						test cases.

	* only -a				If only this option specified, then script will run
						all the DPDK example applications automatically and at the
						end an option will be given to the user which specify whether
						to test the Cunit or not. If user press 'y' then script will
						run all the Cunit test cases automatically also.

	* only -c				If only this option specified, then script will run only
						Cunit test cases. An option will be given to the user
						which will describes that whether to run the script in auto mode
						or not.

	* neither -c nor -a			If none of these options is there, then script will run in manual
						mode even for Cunit test cases.


Assumptions:
	* dynamic_dpl.sh, kernel-ni.sh and loopback_sanity_test.sh all these three scripts
	  are present in the 'usr/bin/dpdk-example/extras' directory.
	* All DPDK example binaries are present in the '/usr/bin/dpdk-example' directory.
	* There are sufficient resources available to create two DPDK conatiners and 3 kernel interfaces.
	* There is sufficient memory to run two DPDK applications concurrently. Script is verified with
	  following bootargs:
	  (bootargs=console=ttyS1,115200 root=/dev/ram0 earlycon=uart8250,mmio,0x21c0600,115200
	   ramdisk_size=2000000 default_hugepagesz=1024m hugepagesz=1024m hugepages=8)

Note:	Minimum running time of script for all test cases is 30 mins.
	"

}

developer_help() {
	echo
	echo -e "\tDeveloper's Help:

	###############################################################################
	############ Sanity script will have following Resources ######################
	###############################################################################
	3 kernel interfaces and 2 containers will be created for the testing, having
	following number of DPNIs objects:

	KERNEL => NI, NI2, NI3
	FDPRC => FDPNI0, FDPNI1, FDPNI2
	SDPRC => SDPNI0, SDPNI1

	These DPNIs will be connected as:

		________________________________________________
	       |			___________________     |
	       |		       |		   |    |
	   NI3 |		FDPNI1 |	    SDPNI0 |    | SDPNI1
	==============		==============          ============
	|   kernel   |		|   FDPRC    |		|   SDPRC  |
	|	     |		|	     |		|          |
	==============		==============		============
	NI |	  | NI2	     FDPNI2|	| FDPNI0
	   |	  |________________|	|
	   |____________________________|

	MAC addresses to these DPNIs will be as:

	NI  = 00:00:00:00:08:01
	NI2 = 00:00:00:00:08:02
	NI3 = 00:00:00:00:08:03

	FDPNI0 = 00:00:00:00:5:1
	FDPNI1 = 00:00:00:00:5:2
	FDPNI2 = 00:00:00:00:5:3

	SDPNI0 = 00:00:00:00:6:1
	SDPNI1 = 00:00:00:00:5:2

	Namespaces and kernel interfaces:

	* Interface NI will be in the default namespace having IP address 192.168.111.2
	* Interface NI2 will be in 'sanity_ns' namespace having IP address 192.168.222.2
	* Interface NI3 will be in 'sanity_ipsec_ns' namespace having IP address 192.168.222.2

DPDK EXAMPLE APPLICATIONS: Method to add an DPDk example application as test case:

Test case command syntax:
	run_command <arguments ...>

Mandatory arguments:
	argument1	Test module	First argument should be Test Module, which is predefined
					Macro for each DPDK application as:
					PKT_TESTPMD	=> testpmd
					PKT_L2FWD  	=> l2fwd
					PKT_L3FWD	=> l3fwd

	argument2	command		Actual command to run.

Process of testing:
	* l2fwd:
		---- ping with destination 192.168.111.1, packets will go through NI, so only FDPNI0 is valid
		     for testing. Results are based on %age packets received.

	* l3fwd
		---- with iperf, only FDPNI0 and FDPNI1 should be used for testing. Results are based on
		     %ge packets loss while iperf testing.


Example:
	run_command PKT_l2FWD "./l2fwd -c 0x3 -n 1 -- -p 0x5 -q 1"

	All these commands should be added only in run_dpdk() function.


	"
}

#/* Function to append new lines into sanity_log file*/
append_newline() {
	num=0
	while [[ $num -lt $1 ]]
	do
		echo >> sanity_log
		num=`expr $num + 1`
	done
}

#Checking if resources are already available
check_resources () {
	#checking kernel interfaces are available or not.
	if [[ -z $NI || -z $NI2 ]]
	then
		return 1;
	fi

	#checking sanity script containers
	if [[ -z $FDPRC || -z $FDPNI0 || -z $FDPNI1 || -z $FDPNI2 ]]
	then
		return 1;
	fi
	if [[ -z $SDPRC || -z $SDPNI0 || -z $SDPNI1 ]]
	then
		return 1;
	fi

	return 0;
}

#creating the required resources
get_resources() {
	#/*
	# * creating the container "FDPRC" with 3 DPNIs which will not be connected to
	# * any object.
	# */
	. ./dynamic_dpl.sh dpni dpni dpni
	FDPRC=$DPRC
	FDPNI0=$DPNI1
	FDPNI1=$DPNI2
	FDPNI2=$DPNI3

	#/*
	# * creating the 2nd container "SDPRC" with 2 DPNIs in which one will be connected to
	# * the first DPNI of first conatiner and 2nd DPNI will remain unconnected.
	# */
	. ./dynamic_dpl.sh $FDPNI1 dpni
	SDPRC=$DPRC
	SDPNI0=$DPNI1
	SDPNI1=$DPNI2

	#/*Creating the required linux interfaces and connecting them to the reaquired DPNIs*/

	./kernel-ni.sh $FDPNI0 | tee linux_iflog
	NI=`grep -o "interface: ni\w*" linux_iflog | sed -e 's/interface: //g'`

	./kernel-ni.sh $FDPNI2 | tee linux_iflog
	NI2=`grep -o "interface: ni\w*" linux_iflog | sed -e 's/interface: //g'`

	./kernel-ni.sh $SDPNI1 | tee linux_iflog
	NI3=`grep -o "interface: ni\w*" linux_iflog | sed -e 's/interface: //g'`

	rm linux_iflog
}


# Function to print results of the most of test cases.
print_result() {
	echo "Recieved $1 packets"
	if [[ "$1" == "$2" ]]
	then
		echo -e $GREEN "\tno packet loss"$NC
		echo -e "\tNo packet loss  ----- PASSED" >> sanity_tested_apps
		passed=`expr $passed + 1`
	elif [[ "$1" -lt "$2" ]]
	then
		echo -e $RED "\t$((1-2))"" packets loss"$NC
		echo -e "\t""$1"" packets loss  ----- FAILED" >> sanity_tested_apps
		failed=`expr $failed + 1`
	elif [[ -z "$1" ]]
	then
		echo -e $RED "\tUnable to capture Results"$NC
		echo -e "\tunable to capture Results  ----- N/A" >> sanity_tested_apps
		na=`expr $na + 1`
	else
		echo -e $GREEN "\t"" All packets recieved"$NC
		echo -e "\t""$1""All packets rcvd  ----- PARTIAL PASSED" >> sanity_tested_apps
		partial=`expr $partial + 1`
	fi
}

#/* Function to run the DPDK Testpmd test cases*/
run_pkt_testpmd() {
echo -e " #$test_no)\tTest case:$1    \t\tCommand:($2) "
echo
eval $PRINT_MSG
$READ
if [[ "$input" == "y" ]]
then
	echo -e " #$test_no)\t$1\t\tcommand ($2) " >> sanity_log
	echo -e " #$test_no)\tTest case:$1    \t\tCommand:($2) " >> sanity_tested_apps
	append_newline 1
	echo
	tcpdump -nt -i $NI >> log3 &
	ip netns exec sanity_ns tcpdump -nt -i $NI2 | tee log1 &
	timeout -k 9 9 $2
	#eval "$2 >> sanity_log 2>&1 &"
	echo
	sleep 5
	append_newline 3
	#ip netns exec sanity_ns tcpdump -nt -i $NI2 | tee log1 &
	sleep 6
	append_newline 3
	echo " Starting the ping test ..."
	#tcpdump -nt -i $NI | tee log3 &
	#ping 192.168.111.1 -c $ping_packets | tee log
	sleep 2
	#ip netns exec sanity_ns killall tcpdump
	#killall tcpdump
	#RESULT=`grep -o "\w*\.\w*%\|\w*%" log`
	#RESULT=`grep -c "IP 192.168.111.2 > 192.168.111.1: ICMP echo request" log1`
	echo
	cat log >> sanity_log
	print_result "$RESULT" "$ping_packets"
	pid=`ps | pgrep testpmd`
	if [[ -z "$pid" ]]
	then
		pid=`ps | pgrep testpmd`
	fi
	kill -2 $pid
	append_newline 5
	rm log
	rm log1
	echo
	echo
	echo
	echo >> sanity_tested_apps
else
	echo -e " #$test_no)\tTest case:$1    \t\tCommand:($2) " >> sanity_untested_apps
	echo -e "\tNot Tested" | tee -a sanity_untested_apps
	not_tested=`expr $not_tested + 1`
	echo
	echo >> sanity_untested_apps
fi
test_no=`expr $test_no + 1`
}
#/* Function to run the DPDK L2fwd test cases*/
run_pkt_l2fwd() {
echo -e " #$test_no)\tTest case:$1    \t\tCommand:($2) "
echo
eval $PRINT_MSG
$READ
if [[ "$input" == "y" ]]
then
	echo -e " #$test_no)\t$1\t\tcommand ($2) " >> sanity_log
	echo -e " #$test_no)\tTest case:$1    \t\tCommand:($2) " >> sanity_tested_apps
	append_newline 1
	echo
	eval "$2 >> sanity_log 2>&1 &"
	echo
	sleep 5
	append_newline 3
	ip netns exec sanity_ns tcpdump -nt -i $NI2 >> log1 &
	sleep 6
	append_newline 3
	echo " Starting the ping test ..."
	echo " Sending $ping_packets Packets"
	ping 192.168.111.1 -c $ping_packets >>  log
	sleep 2
	ip netns exec sanity_ns killall tcpdump
	RESULT=`grep -c "IP 192.168.111.2 > 192.168.111.1: ICMP echo request" log1`
	echo
	cat log >> sanity_log
	print_result "$RESULT" "$ping_packets"
	pid=`ps | pgrep l2fwd`
	if [[ -z "$pid" ]]
	then
		pid=`ps | pgrep l2fwd`
	fi
	kill -2 $pid
	append_newline 5
	rm log
	rm log1
	echo
	echo
	echo
	echo >> sanity_tested_apps
else
	echo -e " #$test_no)\tTest case:$1    \t\tCommand:($2) " >> sanity_untested_apps
	echo -e "\tNot Tested" | tee -a sanity_untested_apps
	not_tested=`expr $not_tested + 1`
	echo
	echo >> sanity_untested_apps
fi
test_no=`expr $test_no + 1`
}

#/* Function to run the DPDK L3fwd test cases*/
run_pkt_l3fwd() {
echo -e " #$test_no)\tTest case:$1    \t\tCommand:($2) "
echo
eval $PRINT_MSG
$READ
if [[ "$input" == "y" ]]
then
	echo -e " #$test_no)\t$1\t\tcommand ($2) " >> sanity_log
	echo -e " #$test_no)\tTest case:$1    \t\tCommand:($2) " >> sanity_tested_apps
	append_newline 1
	echo
	eval "$2 >> sanity_log 2>&1 &"
	echo
	sleep 5
	append_newline 3
	tcpdump -nt -i $NI >> log2 &
	sleep 6
	append_newline 3
	echo " Starting the ping test ..."
	echo " Sending $ping_packets Packets"
	ping 192.168.111.1 -c $ping_packets >> log
	sleep 2
	killall tcpdump
	RESULT=`grep -c "IP 192.168.111.2 > 192.168.111.1: ICMP echo request" log2`
	cat log >> sanity_log
	#res='expr $RESULT - $ping_packets'
	res=$((RESULT - ping_packets))
	print_result "$res" "$ping_packets"
	pid=`ps | pgrep l3fwd`
	if [[ -z "$pid" ]]
	then
		pid=`ps | pgrep l3fwd`
	fi
	kill -2 $pid
	append_newline 5
	rm log2
	rm log
	echo
	echo
	echo
	echo >> sanity_tested_apps
else
	echo -e " #$test_no)\tTest case:$1    \t\tCommand:($2) " >> sanity_untested_apps
	echo -e "\tNot Tested" | tee -a sanity_untested_apps
	not_tested=`expr $not_tested + 1`
	echo
	echo >> sanity_untested_apps
fi
test_no=`expr $test_no + 1`
}

#/* Common function to run all test cases*/

run_command() {
case $1 in
	PKT_TESTPMD )
		run_pkt_testpmd $1 "$2"
		;;
	PKT_l2FWD )
		run_pkt_l2fwd $1 "$2"
		;;
	PKT_l3FWD )
		run_pkt_l3fwd $1 "$2"
		;;
	*)
		echo "Invalid test case $1"
esac
}

#function to run DPDK example applications
run_dpdk() {

	#/* DPDK L2FWD App
	# */
	run_command PKT_l2FWD "./l2fwd -c 0x3 -n 1 -- -p 0x5 -q 1"

	#/* DPDK L3FWD App
	# */
	run_command PKT_l3FWD './l3fwd -c 0x1 -n 1 -- -p 0x1 --config="(0,0,0)" -P'

	#/* DPDK TESTPMD App
	# */
	#run_command PKT_TESTPMD "./testpmd -c 3 -n 1 -- -i --nb-cores=1 --nb-ports=4 --total-num-mbufs=1025 --forward-mode=txonly --disable-hw-vlan --port-topology=chained --no-flush-rx -a"

}

#/* configuring the interfaces*/

configure_ethif() {
	ifconfig $NI 192.168.111.2
	ifconfig $NI hw ether 00:00:00:00:08:01
	ip route add 192.168.222.0/24 via 192.168.111.1
	arp -s 192.168.111.1 000000000501
	ip netns add sanity_ns
	ip link set $NI2 netns sanity_ns
	ip netns exec sanity_ns ifconfig $NI2 192.168.222.2
	ip netns exec sanity_ns ifconfig $NI2 hw ether 00:00:00:00:08:02
	ip netns exec sanity_ns ip route add 192.168.111.0/24 via 192.168.222.1
	ip netns exec sanity_ns arp -s 192.168.222.1 000000000503
	ip netns add sanity_ipsec_ns
	ip link set $NI3 netns sanity_ipsec_ns
	ip netns exec sanity_ipsec_ns ifconfig $NI3 192.168.222.2
	ip netns exec sanity_ipsec_ns ifconfig $NI3 hw ether 00:00:00:00:08:03
	ip netns exec sanity_ipsec_ns ip route add 192.168.111.0/24 via 192.168.222.1
	ip netns exec sanity_ipsec_ns arp -s 192.168.222.1 000000000502
	cd /usr/bin/dpdk-example
	echo
	echo
	echo
}

unconfigure_ethif() {
	ip netns del sanity_ipsec_ns
	ip netns del sanity_ns
	ifconfig $NI down
	cd -
}

main() {
	if [[ ($input != y) ]]
	then
		export DPRC=$FDPRC
		echo "############################################## TEST CASES ###############################################" >> sanity_tested_apps
		echo >> sanity_tested_apps
		run_dpdk
	fi

	echo "############################################## TEST REPORT ################################################" >> result
	echo >> result
	echo >> result
	echo -e "\tDPDK EXAMPLE APPLICATIONS:" >> result
	echo >> result
	echo -e "\tNo. of passed DPDK examples test cases                \t\t= $passed" >> result
	echo -e "\tNo. of failed DPDK examples test cases                \t\t= $failed" >> result
	echo -e "\tNo. of partial passed DPDK examples test cases        \t\t= $partial" >> result
	echo -e "\tNo. of DPDK examples test cases with unknown results  \t\t= $na" >> result
	echo -e "\tNo. of untested DPDK example test cases              \t\t= $not_tested" >> result
	echo -e "\tTotal number of DPDK example test cases	              \t\t= `expr $test_no - 1`" >> result
	echo >> result
	mv /usr/bin/dpdk-example/sanity_log /usr/bin/dpdk-example/extras/sanity_log
	mv /usr/bin/dpdk-example/sanity_tested_apps /usr/bin/dpdk-example/extras/sanity_tested_apps
	if [[ -e "/usr/bin/dpdk-example/sanity_untested_apps " ]]
	then
		mv /usr/bin/dpdk-example/sanity_untested_apps /usr/bin/dpdk-example/extras/sanity_untested_apps
	fi
	echo
	cat result
	echo
	echo >> result
	echo -e "NOTE:  Test results are based on applications logs, If there is change in any application log, results may go wrong.
\tSo it is always better to see console log and sanity_log to verify the results." >> result
	echo >> result
	cat result > /usr/bin/dpdk-example/extras/sanity_test_report
	rm result
	echo
	echo
	echo -e " COMPLETE LOG			=> $GREEN/usr/bin/dpdk-example/extras/sanity_log $NC"
	echo
	echo -e " SANITY TESTED APPS REPORT	=> "$GREEN"/usr/bin/dpdk-example/extras/sanity_tested_apps"$NC
	echo
	echo -e " SANITY UNTESTED APPS		=> "$GREEN"/usr/bin/dpdk-example/extras/sanity_untested_apps"$NC
	echo
	echo -e " SANITY REPORT			=> "$GREEN"/usr/bin/dpdk-example/extras/sanity_test_report"$NC
	echo
	echo " Sanity testing is Done."
	echo
}


# script's starting point
set -m
test_no=1
ping_packets=10
not_tested=0
passed=0
failed=0
partial=0
na=0
input=

#/*
# * Parsing the arguments.
# */
if [[ -z "$1" ]]
then
	PRINT_MSG="echo -e \"\tEnter 'y' to execute the test case\""
	READ="read input"
else
	for i in "$@"
	do
		case $i in
			-h)
				help
				[[ "${BASH_SOURCE[0]}" != $0 ]] && return || exit
				;;
			-d)
				developer_help
				[[ "${BASH_SOURCE[0]}" != $0 ]] && return || exit
				;;
			-p=*)
				ping_packets="${i#*=}"
				;;
			-a)
				PRINT_MSG=
				READ=
				input=y
				;;
			*)
				echo "Invalid option $i"
				help
				[[ "${BASH_SOURCE[0]}" != $0 ]] && return || exit
				;;
		esac
	done
fi

if [[ -e "/usr/bin/dpdk-example/extras/sanity_log" ]]
then
	rm /usr/bin/dpdk-example/extras/sanity_log
fi

if [[ -e "/usr/bin/dpdk-example/extras/sanity_tested_apps" ]]
then
	rm /usr/bin/dpdk-example/extras/sanity_tested_apps
fi

if [[ -e "/usr/bin/dpdk-example/extras/sanity_untested_apps" ]]
then
	rm /usr/bin/dpdk-example/extras/sanity_untested_apps
fi

if [[ -e "/usr/bin/dpdk-example/extras/sanity_test_report" ]]
then
	rm /usr/bin/dpdk-example/extras/sanity_test_report
fi

#/* Variables represent colors */
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

check_resources
RET=$?
if [[ $RET == 1 ]]
then
	get_resources
fi
configure_ethif
main
unconfigure_ethif
set +m
