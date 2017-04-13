#/*
# * Copyright (c) 2017 NXP Semiconductor, Inc. All rights reserved.
# */

help() {
	echo
	echo "USAGE: . ./loopback_ipfragment-reassembly.sh <options>
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
	. ./loopback_ipfragment-reassembly.sh -a        OR     source ./loopback_ipfragment-reassembly.sh -a

Options and Sanity script running behaviour:

	OPTIONS					SCRIPT BEHAVIOUR



	* only -a				If only this option specified, then script will run
						all the DPDK example applications automatically.



	* without any option  If none of these options is there, then script will run in manual
						mode and user input  'y' require for procedding testcase one by one


Assumptions:
	* dynamic_dpl.sh, kernel-ni.sh and loopback_sanity_test.sh all these three scripts
	  are present in the 'usr/bin/dpdk-example/extras' directory.
	* All DPDK example binaries are present in the '/usr/bin/dpdk-example' directory.
	* There are sufficient resources available to create two DPDK conatiners and 4 kernel interfaces.
	* There is sufficient memory to run two DPDK applications concurrently. Script is verified with
	  following bootargs:
	  (bootargs=console=ttyS1,115200 root=/dev/ram0 earlycon=uart8250,mmio,0x21c0600,115200
	   ramdisk_size=2000000 default_hugepagesz=1024m hugepagesz=1024m hugepages=8)

Note:	Minimum running time of script for all test cases is xx mins.

	option:
	option-1	verify ip_fragmentation and ip_reassembly for different ping packet size like 1000,2000,4000,9000
	option-2	verify ip_fragmentation and ip_reassembly for different ping packet size with min to max packet size with step. 
	"

}

developer_help() {
	echo
	echo -e "\tDeveloper's Help:

	###############################################################################
	############ Sanity script will have following Resources ######################
	###############################################################################
	4 kernel interfaces and 2 containers will be created for the testing, having
	following number of DPNIs objects:

	KERNEL => NI, NI2, NI3, NI4
	FDPRC => FDPNI0, FDPNI1, FDPNI2, FDPNI3
	SDPRC => SDPNI0, SDPNI1, SDPNI2, SDPNI3

	These DPNIs will be connected as:

   
				_________________________________________________
				|	    _____________________               |
				|          |		   	 |	    	|
				|FDPNI1    | FDPNI0	   	 |SDPNI2        | SDPNI3
          			==================		====================
				|   FDPRC    	  |		|   SDPRC  	   |
				|          	  |		|		   |
				==================		====================
			         |FDPNI2    | FDPNI3		 |SDPNI0       |SDPNI1
				 |	    |			 |     	       |
				 |	    |  		         |             |
				 |	    |    		 |	       |
	 			 |NI	    |NI2		 |NI3	       |NI4
     				===================================================
				|			kernel   		  |	
				|	     		                          | 	
				===================================================

	MAC addresses to these DPNIs will be as:

	NI  = 02:00:00:00:00:02
	NI2 = 02:00:00:00:00:03
	NI3 = 02:00:00:00:00:00
	NI4 = 02:00:00:00:00:01

	FDPNI0 = 00:00:00:00:5:1
	FDPNI1 = 00:00:00:00:5:2
	FDPNI2 = 00:00:00:00:5:3
	FDPNI3 = 00:00:00:00:5:4
	

	SDPNI0 = 00:00:00:00:6:1
	SDPNI1 = 00:00:00:00:6:2
	SDPNI2 = 00:00:00:00:6:3
	SDPNI3 = 00:00:00:00:6:4
	

	Namespaces and kernel interfaces:

	* Interface NI will be in the default namespace having   IP address 100.30.0.10
	* Interface NI2 will be in sanity_port2 namespace having IP address 100.40.0.10
	* Interface NI3 will be in sanity_port3 namespace having IP address 100.10.0.10
	* Interface NI4 will be in sanity_port4 namespace having IP address 100.20.0.10

DPDK EXAMPLE APPLICATIONS: Method to add an DPDk example application as test case:

Test case command syntax:
	run_command <arguments ...>

Mandatory arguments:
	argument1	Test module	First argument should be Test Module, which is predefined
					Macro for each DPDK application as:
					PKT_IPFRAGMENT_REASSEMBLY	=> ip_fragmentation and ip_reassembly
					

	argument2	command		Actual command to run.

Process of testing:
	* ip_fragmentation and ip_reassembly:
		---- on this script two application ip_fragmentation run on  FDPRC  and ip_reassembly run on  SDPRC ping packet will first fragment on FDPRC and reseambly on SDPRC.




Example:
	run_command PKT_IPFRAGMENT_REASSEMBLY   './ip_fragmentation -c 0xf -n 1 --file-prefix=p1 --socket-mem=1024 -- -p 0x5'  './ip_reassembly -c 0xf0 -n 4 --file-prefix=p2 --socket-mem=2048 -- -p 0x5'  "option-1"
    
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
        if [[ -z $NI || -z $NI2 || -z $NI3 || -z $NI4 ]]
        then
                return 1;
        fi

        #checking sanity script containers
        if [[ -z $FDPRC || -z $FDPNI0 || -z $FDPNI1 || -z $FDPNI2 ||  -z $FDPNI3 ]]
        then
                return 1;
        fi
        if [[ -z $SDPRC || -z $SDPNI0 || -z $SDPNI1 || -z $SDPNI2 || -z $SDPNI3 ]]
        then
                return 1;
        fi

        return 0;

}

#creating the required resources
get_resources() {
	#/*
	# * creating the container "FDPRC" with 4 DPNIs which will not be connected to
	# * any object.
	# */
 	source ${DPDK_PATH}/extras/dynamic_dpl.sh dpni dpni dpni dpni
	FDPRC=$DPRC
	FDPNI0=$DPNI1
	FDPNI1=$DPNI2
	FDPNI2=$DPNI3
	FDPNI3=$DPNI4
	
	sleep 5
	
	source ${DPDK_PATH}/extras/dynamic_dpl.sh  dpni dpni $FDPNI0 $FDPNI1 -b 00:00:00:00:06:00
	SDPRC=$DPRC
	SDPNI0=$DPNI1
	SDPNI1=$DPNI2
	SDPNI2=$DPNI3
	SDPNI3=$DPNI4
	
	#/*Creating the required linux interfaces and connecting them to the reaquired DPNIs*/

	source ${DPDK_PATH}/extras/kernel-ni.sh $FDPNI2 | tee linux_iflog
	NI=`grep -o "interface: ni\w*" linux_iflog | sed -e 's/interface: //g'`

	source ${DPDK_PATH}/extras/kernel-ni.sh $FDPNI3 | tee linux_iflog
	NI2=`grep -o "interface: ni\w*" linux_iflog | sed -e 's/interface: //g'`

	source ${DPDK_PATH}/extras/kernel-ni.sh $SDPNI0 | tee linux_iflog
	NI3=`grep -o "interface: ni\w*" linux_iflog | sed -e 's/interface: //g'`

	source ${DPDK_PATH}/extras/kernel-ni.sh $SDPNI1 | tee linux_iflog
	NI4=`grep -o "interface: ni\w*" linux_iflog | sed -e 's/interface: //g'`
	rm linux_iflog
}


# Function to print results of the most of test cases.
print_result() {
	if [[ "$1" == "0%" ]]
	then
		echo -e $GREEN "\tno packet loss"$NC
		echo -e "\t packet-size "$2"Bytes\tNo packet loss  ----- PASSED" >> sanity_tested_apps
		passed=`expr $passed + 1`
	elif [[ "$1" == "100%" ]]
	then
		echo -e $RED "\t$1"" packets loss"$NC
		echo -e "\t packet-size "$2"Bytes\t""$1"" packets loss  ----- FAILED" >> sanity_tested_apps
		failed=`expr $failed + 1`
	elif [[ -z "$1" ]]
	then
		echo -e $RED "\tUnable to capture Results"$NC
		echo -e "\tunable to capture Results  ----- N/A" >> sanity_tested_apps
		na=`expr $na + 1`
	else
		echo -e $RED "\t$1"" packets loss"$NC
		echo -e "\t packet-size "$2"Bytes\t""$1"" packets loss  ----- PARTIAL PASSED" >> sanity_tested_apps
		partial=`expr $partial + 1`
	fi
}

#/* Function to run the DPDK IP-FRAGMENT and REASSEMBLY  test cases*/

run_ipfragment_reassembly() {
echo -e " #$test_no)\tTest case:$1  \n  \t\tCommand:($2)  \n \t\tCommand:($3) n \t\tCommand:($4)"
echo
eval $PRINT_MSG
$READ
if [[ "$input" == "y" ]]
then
	echo -e " #$test_no)\t$1\t\tcommand ($2) " >> sanity_log
	echo -e " #$test_no)\tTest case:$1  \n  \t\tCommand:($2)  \n \t\tCommand:($3) n \t\tCommand:($4)" >> sanity_tested_apps
	append_newline 1
	echo
	export DPRC=$FDPRC
	eval "$2 >> sanity_log 2>&1 &"
        sleep 10
	export DPRC=$SDPRC
	eval "$3 >> sanity_log 3>&2 &"
         
	echo
	sleep 10 
	append_newline 3
  	
	if [[ "$4" == "option-1" ]]
	then
		
		for pkt_size in $pkt_list
		do
			ping -f 100.10.0.10 -c $ping_packets -s $pkt_size | tee log
			RESULT=`grep -o "\w*\.\w*%\|\w*%" log`
			print_result "$RESULT" "$pkt_size"
			sleep 5
			cat log >> sanity_log
		done
		
		
	elif [[ "$4" == "option-2" ]]
	then
	    min=$min_pkt_size
		while [[ $min -lt $max_pkt_size ]]
		do
			ping -f 100.10.0.10 -c $ping_packets -s $min | tee log
			RESULT=`grep -o "\w*\.\w*%\|\w*%" log`
			print_result "$RESULT" "$min"
			sleep 5
			cat log >> sanity_log
			min=`expr $min + $step`
		done

				
	else
		echo -e $RED "\t$4"" Wrong option  Configured"
		echo -e "\t""$4"" Wrong option  Configured" >> sanity_tested_apps
		
	fi
 
    killall ip_reassembly ip_fragmentation
	append_newline 5
	rm log
	echo
	sleep 15
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
	PKT_IPFRAGMENT_REASSEMBLY )
		run_ipfragment_reassembly $1 "$2" "$3" "$4"
		;;
	*)
		echo "Invalid test case $1"
esac
}

#function to run DPDK example applications
run_dpdk() {

	#/* DPDK IPFRAGMENT and REASSEMBLY App
	# */
	run_command PKT_IPFRAGMENT_REASSEMBLY   './ip_fragmentation -c 0xf -n 1 --file-prefix=p1 --socket-mem=1024 -- -p 0x5'  './ip_reassembly -c 0xf0 -n 4 --file-prefix=p2 --socket-mem=2048 -- -p 0x5'  "option-1"
    run_command PKT_IPFRAGMENT_REASSEMBLY   './ip_fragmentation -c 0xf -n 1 --file-prefix=p1 --socket-mem=1024 -- -p 0x5'  './ip_reassembly -c 0xf0 -n 4 --file-prefix=p2 --socket-mem=2048 -- -p 0x5'  "option-2"
}

#/* configuring the interfaces*/

configure_ethif() {

	ifconfig $NI 100.30.0.10
	ifconfig $NI hw ether 02:00:00:00:00:02
	ip route add 100.10.0.0/24 via 100.30.0.1
	arp -s 100.30.0.1 000000000503
	
	ip netns add sanity_port2
	ip link set $NI2 netns sanity_port2
	ip netns exec sanity_port2 ifconfig $NI2 100.40.0.10
	ip netns exec sanity_port2 ifconfig $NI2 hw ether 02:00:00:00:00:03
	ip netns exec sanity_port2 ip route add 100.20.0.0/24 via 100.40.0.1
	ip netns exec sanity_port2 arp -s 100.40.0.1 000000000504

	ip netns add sanity_port3
	ip link set $NI3 netns sanity_port3
	ip netns exec sanity_port3 ifconfig $NI3 100.10.0.10
	ip netns exec sanity_port3 ifconfig $NI3 hw ether 02:00:00:00:00:00
	ip netns exec sanity_port3 ip route add 100.30.0.0/24 via 100.10.0.1
	ip netns exec sanity_port3 arp -s 100.10.0.1 000000000601
	
	
	
	ip netns add sanity_port4
	ip link set $NI4 netns sanity_port4
	ip netns exec sanity_port4 ifconfig $NI4 100.20.0.10
	ip netns exec sanity_port4 ifconfig $NI4 hw ether 02:00:00:00:00:01
	ip netns exec sanity_port4 ip route add 100.40.0.0/24 via 100.20.0.1
	ip netns exec sanity_port4 arp -s 100.20.0.1 000000000602
	

	cd ${DPDK_PATH}
	echo
	echo
	echo
}

unconfigure_ethif() {
        
	ip netns del sanity_port2
	ip netns del sanity_port3
	ip netns del sanity_port4
	ifconfig $NI down
	source ${DPDK_PATH}/extras/destroy_dynamic_dpl.sh $FDPRC
	source ${DPDK_PATH}/extras/destroy_dynamic_dpl.sh $SDPRC
	source ${DPDK_PATH}/extras/destroy_dpni.sh

	cd -
}

main() {

	export DPRC=$FDPRC
	if [ ! -v ALL_TEST ]
	then 
		echo "############################################## TEST CASES ###############################################" >> sanity_tested_apps
		echo >> sanity_tested_apps
	fi
	run_dpdk
	
	
	unconfigure_ethif
	if [ ! -v ALL_TEST ]
	then 
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
		mv ${DPDK_PATH}/sanity_log ${DPDK_PATH}/extras/sanity_log
		mv ${DPDK_PATH}/sanity_tested_apps ${DPDK_PATH}/extras/sanity_tested_apps
		if [[ -e "${DPDK_PATH}/sanity_untested_apps " ]]
		then
			mv ${DPDK_PATH}/sanity_untested_apps ${DPDK_PATH}/extras/sanity_untested_apps
		fi
		echo
		cat result
		echo
		echo >> result
		echo -e "NOTE:  Test results are based on applications logs, If there is change in any application log, results may go wrong.
	\tSo it is always better to see console log and sanity_log to verify the results." >> result
		echo >> result
		cat result > ${DPDK_PATH}/extras/sanity_test_report
		rm result
		echo
		echo
		echo -e " COMPLETE LOG			=> $GREEN${DPDK_PATH}/extras/sanity_log $NC"
		echo
		echo -e " SANITY TESTED APPS REPORT	=> "$GREEN"${DPDK_PATH}/extras/sanity_tested_apps"$NC
		echo
		echo -e " SANITY UNTESTED APPS		=> "$GREEN"${DPDK_PATH}/extras/sanity_untested_apps"$NC
		echo
		echo -e " SANITY REPORT			=> "$GREEN"${DPDK_PATH}/extras/sanity_test_report"$NC
		echo
		echo " Sanity testing is Done."
		echo
	fi
}


# script's starting point
DPDK_PATH=/usr/bin/dpdk-example

set -m

ping_packets=320
pkt_list="100 1000 2000 4000 9000"
max_pkt_size=9000
min_pkt_size=100
step=500
if [ ! -v ALL_TEST ]
then
	test_no=1
	not_tested=0
	passed=0
	failed=0
	partial=0
fi
na=0
input=

#/*
# * Parsing the arguments.
# */
if [[ $1 ]]
then
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

if [[ $input != "y" ]]
then
	PRINT_MSG="echo -e \"\tEnter 'y' to execute the test case\""
	READ="read input"
fi

if [[ -e "${DPDK_PATH}/extras/sanity_log" ]]
then
	rm ${DPDK_PATH}/extras/sanity_log
fi

if [[ -e "${DPDK_PATH}/extras/sanity_tested_apps" ]]
then
	rm ${DPDK_PATH}/extras/sanity_tested_apps
fi

if [[ -e "${DPDK_PATH}/extras/sanity_untested_apps" ]]
then
	rm ${DPDK_PATH}/extras/sanity_untested_apps
fi

if [[ -e "${DPDK_PATH}/extras/sanity_test_report" ]]
then
	rm ${DPDK_PATH}/extras/sanity_test_report
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
else 
source ${DPDK_PATH}/extras/destroy_dynamic_dpl.sh $FDPRC
source ${DPDK_PATH}/extras/destroy_dynamic_dpl.sh $SDPRC	
source ${DPDK_PATH}/extras/destroy_dpni.sh
get_resources
fi
configure_ethif
main

set +m
