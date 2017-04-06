#/*
# * Copyright (c) 2017 NXP Semiconductor, Inc. All rights reserved.
# */

help() {
	echo
	echo "USAGE: . ./loopback_ipsec_secgw.sh <options>
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
	  source ./loopback_ipsec_secgw.sh -a

Options and Sanity script running behaviour:

	OPTIONS					SCRIPT BEHAVIOUR



	* only -a				If only this option specified, then script will run
						all the DPDK example applications automatically and at the
						end an option will be given to the user which specify whether
						to test the Cunit or not. If user press 'y' then script will
						run all the Cunit test cases automatically also.



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
				|FDPNI1    | FDPNI0	   	 |SDPNI0        | SDPNI1
          			==================		====================
				|   FDPRC    	  |		|   SDPRC  	   |
				|          	  |		|		   |
				==================		====================
			         |FDPNI2    | FDPNI3		 |SDPNI2       |SDPNI3
				 |	    |			 |     	       |
				 |	    |  		         |             |
				 |	    |    		 |	       |
	 			 |NI	    |NI2		 |NI3	       |NI4
     				===================================================
				|			kernel   		  |	
				|	     		                          | 	
				===================================================

	MAC addresses to these DPNIs will be as:

	NI  = 00:16:3e:08:69:26
	NI2 = 00:16:3e:49:9e:dd
	NI3 = 00:16:3e:08:69:26
	NI4 = 00:16:3e:49:9e:dd

	FDPNI0 = 00:00:00:00:5:1
	FDPNI1 = 00:00:00:00:5:2
	FDPNI2 = 00:00:00:00:5:3
	FDPNI3 = 00:00:00:00:5:4
	

	SDPNI0 = 00:00:00:00:6:1
	SDPNI1 = 00:00:00:00:6:2
	SDPNI2 = 00:00:00:00:6:3
	SDPNI3 = 00:00:00:00:6:4
	

	Namespaces and kernel interfaces:

	* Interface NI will be in the default namespace having IP address 192.168.115.10
	* Interface NI2 will be in sanity_port2 namespace having IP address 192.168.116.10
	* Interface NI3 will be in sanity_port3 namespace having IP address 192.168.105.10
	* Interface NI4 will be in sanity_port4 namespace having IP address 192.168.106.10

DPDK EXAMPLE APPLICATIONS: Method to add an DPDk example application as test case:

Test case command syntax:
	run_command <arguments ...>

Mandatory arguments:
	argument1	Test module	First argument should be Test Module, which is predefined
					Macro for each DPDK application as:
					PKT_IPSEC_SECGW	=> ipsec-secgw
					

	argument2	command		Actual command to run.

Process of testing:
	* ipsec-secgw:
		---- ping with bi-destination 192.168.115.10<->192.168.105.10 and 192.168.116.10<->192.168.106.10




Example:
	run_command PKT_IPSEC_SECGW "./ipsec-secgw -c 0xf  --file-prefix=p1 --socket-mem=1024  -- -p 0xf -P -u 0x3 --config="(0,0,0),(1,0,1),(2,0,2),(3,0,3)"   --ep0"

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
	# * creating the container "FDPRC" with 3 DPNIs which will not be connected to
	# * any object.
	# */
 	source ${DPDK_PATH}/extras/dynamic_dpl.sh dpni dpni dpni dpni
	FDPRC=$DPRC
	FDPNI0=$DPNI1
	FDPNI1=$DPNI2
	FDPNI2=$DPNI3
	FDPNI3=$DPNI4
	#/*
	# * creating the 2nd container "SDPRC" with 2 DPNIs in which one will be connected to
	# * the first DPNI of first conatiner and 2nd DPNI will remain unconnected.
	# */
	source ${DPDK_PATH}/extras/dynamic_dpl.sh $FDPNI0 $FDPNI1 dpni dpni -b 00:00:00:00:06:00
	SDPRC=$DPRC
	SDPNI0=$DPNI1
	SDPNI1=$DPNI2
	SDPNI2=$DPNI3
	SDPNI3=$DPNI4
	#/*Creating the required linux interfaces and connecting them to the reaquired DPNIs*/
	sleep 5
	source ${DPDK_PATH}/extras/kernel-ni.sh $FDPNI2 | tee linux_iflog
	NI=`grep -o "interface: ni\w*" linux_iflog | sed -e 's/interface: //g'`

	source ${DPDK_PATH}/extras/kernel-ni.sh $FDPNI3 | tee linux_iflog
	NI2=`grep -o "interface: ni\w*" linux_iflog | sed -e 's/interface: //g'`

	source ${DPDK_PATH}/extras/kernel-ni.sh $SDPNI2 | tee linux_iflog
	NI3=`grep -o "interface: ni\w*" linux_iflog | sed -e 's/interface: //g'`

	source ${DPDK_PATH}/extras/kernel-ni.sh $SDPNI3 | tee linux_iflog
	NI4=`grep -o "interface: ni\w*" linux_iflog | sed -e 's/interface: //g'`
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

#/* Function to run the DPDK IPSEC-GW  test cases*/

run_ipsec_secgw() {
echo -e " #$test_no)\tTest case:$1  \n  \t\tCommand:($2)  \n \t\tCommand:($3)"
echo
eval $PRINT_MSG
$READ
if [[ "$input" == "y" ]]
then
	echo -e " #$test_no)\t$1\t\tcommand ($2) " >> sanity_log
	echo -e " #$test_no)\tTest case:$1  \n  \t\tCommand:($2)  \n \t\tCommand:($3) " >> sanity_tested_apps
	append_newline 1
	echo
	export DPRC=$FDPRC
	eval "$2 >> sanity_log 2>&1 &"
    sleep 5
	export DPRC=$SDPRC
	eval "$3 >> sanity_log 3>&2 &"
         
	echo
	sleep 10 
	append_newline 3
	
	for pkt_size in $pkt_list
	do
	
		ping  192.168.105.10 -i 0.001 -c $ping_packets
		sleep 5
		ip netns exec sanity_port3 tcpdump -nt -i $NI3 >> log3 &
		sleep 5
		append_newline 3
		echo " Starting the ping test ..."
		echo " Sending $ping_packets Packets"
		ping  192.168.105.10 -i 0.001 -c $ping_packets >> log
		sleep 20
		killall tcpdump
		RESULT=`grep -c "IP 192.168.105.10 > 192.168.115.10: ICMP echo reply" log3`
		cat log >> sanity_log
		print_result $RESULT $ping_packets
		
		sleep 5
		append_newline 3
		ip netns exec  sanity_port2  ping  192.168.106.10 -i 0.001 -c $ping_packets
		sleep 5
		ip netns exec sanity_port4 tcpdump -nt -i $NI4 >> log4 &
		sleep 5
		append_newline 3
		echo " Starting the ping test ..."
		echo " Sending $ping_packets Packets"
		ip netns exec  sanity_port2  ping  192.168.106.10 -i 0.001 -c $ping_packets >> log
		sleep 20
		killall tcpdump
		RESULT=`grep -c "IP 192.168.106.10 > 192.168.116.10: ICMP echo reply" log4`
		cat log >> sanity_log
	   	print_result $RESULT $ping_packets			
			
		sleep 5
		append_newline 3
		ip netns exec sanity_port3 ping  192.168.115.10 -i 0.001 -c $ping_packets
		sleep 5
		tcpdump -nt -i $NI >> log1 &
		sleep 5
		append_newline 3
		echo " Starting the ping test ..."
		echo " Sending $ping_packets Packets"
		ip netns exec sanity_port3 ping  192.168.115.10 -i 0.001 -c $ping_packets >> log
		sleep 20
		killall tcpdump
		RESULT=`grep -c "IP 192.168.115.10 > 192.168.105.10: ICMP echo reply" log1`
		cat log >> sanity_log
	  	print_result $RESULT $ping_packets			
			
		sleep 5 
		append_newline 3
		ip netns exec sanity_port4 ping  192.168.116.10 -i 0.001 -c $ping_packets
		sleep 5
		ip netns exec sanity_port2 tcpdump -nt -i $NI2 >> log2 &
		sleep 6
		append_newline 3
		echo " Starting the ping test ..."
		echo " Sending $ping_packets Packets"
		ip netns exec sanity_port4 ping  192.168.116.10 -i 0.001 -c $ping_packets >> log
		sleep 20
		killall tcpdump
		RESULT=`grep -c "IP 192.168.116.10 > 192.168.106.10: ICMP echo reply" log2`
		cat log >> sanity_log
		print_result $RESULT $ping_packets
		
	done 
       
	
	killall ipsec-secgw
	sleep 10
	append_newline 5

	rm log
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
	PKT_IPSEC_SECGW )
		run_ipsec_secgw $1 "$2" "$3"
		;;
	*)
		echo "Invalid test case $1"
esac
}

#function to run DPDK example applications
run_dpdk() {

	#/* DPDK IPSEC_SECGW App
	# */
	run_command PKT_IPSEC_SECGW   './ipsec-secgw -c 0xf  --file-prefix=p1 --socket-mem=1024  -- -p 0xf -P -u 0x3 --config="(0,0,0),(1,0,1),(2,0,2),(3,0,3)"   --ep0'  './ipsec-secgw -c 0xf0 --file-prefix=p2 --socket-mem=1024 -- -p 0xf -P -u 0x3  --config="(0,0,4),(1,0,5),(2,0,6),(3,0,7)"  --ep1'

}

#/* configuring the interfaces*/

configure_ethif() {
	
	ifconfig $NI 192.168.115.10
	ifconfig $NI hw ether 00:16:3e:08:69:26
	ip route add 192.168.105.0/24 via 192.168.115.3
	arp -s 192.168.115.3 000000000503

	ip netns add sanity_port2
	ip link set $NI2 netns sanity_port2
	ip netns exec sanity_port2 ifconfig $NI2 192.168.116.10
	ip netns exec sanity_port2 ifconfig $NI2 hw ether 00:16:3e:49:9e:dd
	ip netns exec sanity_port2 ip route add 192.168.106.0/24 via 192.168.116.3
	ip netns exec sanity_port2 arp -s 192.168.116.3 000000000504
	
	ip netns add sanity_port3
	ip link set $NI3 netns sanity_port3
	ip netns exec sanity_port3 ifconfig $NI3 192.168.105.10
	ip netns exec sanity_port3 ifconfig $NI3 hw ether 00:16:3e:08:69:26
	ip netns exec sanity_port3 ip route add 192.168.115.0/24 via 192.168.105.3
	ip netns exec sanity_port3 arp -s 192.168.105.3 000000000603
	
	ip netns add sanity_port4
	ip link set $NI4 netns sanity_port4
	ip netns exec sanity_port4 ifconfig $NI4 192.168.106.10
	ip netns exec sanity_port4 ifconfig $NI4 hw ether 00:16:3e:49:9e:dd
	ip netns exec sanity_port4 ip route add 192.168.116.0/24 via 192.168.106.3
	ip netns exec sanity_port4 arp -s 192.168.106.3 000000000604
	

	cd /usr/bin/dpdk-example
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
pkt_list="64"
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
