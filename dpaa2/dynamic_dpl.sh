#/*
# * Copyright (c) 2014-2015 Freescale Semiconductor, Inc. All rights reserved.
# *
# *
# */
cat > script_help << EOF


script help :----->

	Run this script as
	". ./dynamic_dpl.sh dpmac.1 dpmac.2 -b ab:cd:ef:gh:ij:kl dpni-dpni dpni-self..."

	Acceptable arguments are dpni-dpni, dpni-self, dpmac.x and -b

    -b [optional] = Specify the MAC base address and must be followed by
		    a valid MAC base address. If this option is there in
		    command line then MAC addresses to DPNIs will be given as:

		    Base address = ab:cd:ef:gh:ij:kl
				 + 00:00:00:00:00:0I
		                  -------------------
				   Actual MAC address

		    where I is the index of the argument

	dpni-dpni = This specify that 2 DPNIs object will be created,
		    which will be connected back to back.
		    dpni.x <-------connected----->dpni.y

		    If -b option is not given then MAC addresses will be like:

		    dpni.x = 00:00:00:00:02:I
		    dpni.y = 00:00:00:00:03:I
		    where I is the index of the argument "dpni-dpni".

	dpni-self = This specify that 1 DPNI object will be created,
		    which will be connected to itself.
		    dpni.x <-------connected----->dpni.x

		    If -b option is not given then MAC address will be as:

		    dpni.x = 00:00:00:00:04:I
		    where I is the index of the argument "dpni-self".

	     dpni = This specify that 1 DPNI object will be created,
		    which will be unconnect.
		    dpni.x ------------- UNCONNECTED

		    If -b option is not given then MAC address will be as:

		    dpni.x = 00:00:00:00:05:I
		    where I is the index of the argument "dpni".

	   dpni.x = This specify that 1 DPNI (dpni.y) object will be created,
		    which will be connected to dpni.x
		    dpni.y <-------connected----->dpni.x

		    If -b option is not given then MAC address will be as:

		    dpni.y = 00:00:00:00:06:I
		    where I is the index of the argument "dpni.y".

	  dpmac.x = This specify that 1 DPNI  (dpni.y) object will be created,
		    which will be connected to dpmac.x.
		    dpmac.x <-------connected----->dpni.y

		    If -b option is not given then MAC address will be as:

		    dpni.y = 00:00:00:00:00:x
		    where x is the ID of the dpmac.x

	By default, this script will create 4 DPBP, 10 DPIOs, 10 DPCIs, 5 DPCON, 1 DPSEC,
	1 loop (dpni-self) device and DPNIs depend upon the arguments given during command line.

	Note: Please refer to /usr/odp/scripts/dynamic_dpl_logs file for script logs

     Optional configuration parameters:

	Below "ENVIRONMENT VARIABLES" are exported to get user defined
	configuration"
	/**DPNI**:-->
		MAX_SENDERS         = max number of parallel senders on DPNI.
					Set the parameter using below command:
					'export MAX_SENDERS=<Number of senders>'
					where "Number of senders" is an integer
					value "e.g export MAX_SENDERS=8"

		MAX_TCS             = maximum traffic classes for Rx/Tx both.
					Set the parameter using below command:
					'export MAX_TCS=<Num of traffic class>'
					where "Number of traffic classes" is an
					integer value. "e.g export MAX_TCS=8"

		MAX_DIST_PER_TC     = maximum dist 'size per RX traffic class.
					Set the parameter using below command:
					'export MAX_DIST_PER_TC="dist_in_tc1,dist_in_tc2,..."'
					export MAX_DIST_PER_TC="8,8,8,8,8,8,8,8"
					to set 4 distribution in each TC
					Distribution values occurrence must be
					equal to number of MAX_TCS.
				Note: Make sure to modify MAX_DIST_PER_TC if
					MAX_TCS is modified.

		DPNI_OPTIONS        = DPNI related options.
					Set the parameter using below command:
					'export DPNI_OPTIONS="opt-1,opt-2,..."'
					e.g export DPNI_OPTIONS="DPNI_OPT_MULTICAST_FILTER,DPNI_OPT_UNICAST_FILTER,DPNI_OPT_DIST_HASH,DPNI_OPT_DIST_FS,DPNI_OPT_FS_MASK_SUPPORT"

		MAX_DIST_KEY_SIZE   = maximum distribution key size.
					Set the parameter using below command:
					'export MAX_DIST_KEY_SIZE=<Key length>
					 where "key length" is an integer value.
					 e.g. export MAX_DIST_KEY_SIZE=32

	/**DPCON**:-->
		DPCON_COUNT	    = DPCONC objects count
					Set the parameter using below command:
					'export DPCON_COUNT=<Num of dpconc objects>'
					where "Number of dpconc objects" is an
					integer value and greater than 2.
					e.g export DPCON_COUNT=10"

		DPCON_PRIORITIES    = number of priorities 1-8.
					Set the parameter using below command:
					'export DPCON_PRIORITIES=<Num of prio>'
					where "Number of priorities" is an
					integer value.
					e.g export DPCON_PRIORITIES=8."


	/**DPSECI**:-->
		DPSECI_QUEUES       = number of rx/tx queues.
					Set the parameter using below command:
					'export DPSECI_QUEUES=<Num of Queues>'
					where "Number of Queues" is an integer
					value "e.g export DPSECI_QUEUES=8".

		DPSECI_PRIORITIES   = num-queues priorities.
					Set the parameter using below command:
                                        'export DPSECI_PRIORITIES="Prio-1,Prio-2,..."'
                                        e.g export DPSECI_PRIORITIES="2,2,2,2,2,2,2,2"

	/**DPIO**:-->
		DPIO_COUNT	    = DPIO objects count
					Set the parameter using below command:
					'export DPIO_COUNT=<Num of dpio objects>'
					where "Number of dpio objects" is an
					integer value.
					e.g export DPIO_COUNT=10"

		DPIO_PRIORITIES     = number of  priority from 1-8.
					Set the parameter using below command:
                                        'export DPIO_PRIORITIES=<Num of prio>'
					where "Number of priorities" is an
					integer value.
					"e.g export DPIO_PRIORITIES=8"

	/**DPBP**:-->
		DPBP_COUNT	    = DPBP objects count
					Set the parameter using below command:
					'export DPBP_COUNT=<Num of dpbp objects>'
					where "Number of dpbp objects" is an
					integer value.
					e.g export DPBP_COUNT=4"

	/**DPCI**:-->
		DPCI_COUNT	    = DPCI objects count for software queues
					Set the parameter using below command:
					'export DPCI_COUNT=<Num of dpci objects>'
					where "Number of dpci objects" is an
					even number value.
					e.g export DPCI_COUNT=10"

EOF


#/* Function, to intialize the DPNI related parameters
#*/
get_dpni_parameters() {
	if [[ -z "$MAX_SENDERS" ]]
	then
		MAX_SENDERS=8
	fi
	if [[ -z "$MAX_TCS" ]]
	then
		MAX_TCS=1
	fi
	if [[ -z "$MAX_DIST_PER_TC" ]]
	then
		MAX_DIST_PER_TC=8
	fi
	if [[ -z "$DPNI_OPTIONS" ]]
	then
		DPNI_OPTIONS="DPNI_OPT_MULTICAST_FILTER,DPNI_OPT_UNICAST_FILTER,DPNI_OPT_DIST_HASH,DPNI_OPT_DIST_FS,DPNI_OPT_FS_MASK_SUPPORT"
	fi
	if [[ -z "$MAX_DIST_KEY_SIZE" ]]
	then
		MAX_DIST_KEY_SIZE=32
	fi
	echo >> dynamic_dpl_logs
	echo  "DPNI parameters :-->" >> dynamic_dpl_logs
	echo -e "\tMAX_SENDERS = "$MAX_SENDERS >> dynamic_dpl_logs
	echo -e "\tMAX_TCS = "$MAX_TCS >> dynamic_dpl_logs
	echo -e "\tMAX_DIST_PER_TC = "$MAX_DIST_PER_TC >> dynamic_dpl_logs
	echo -e "\tMAX_DIST_KEY_SIZE = "$MAX_DIST_KEY_SIZE >> dynamic_dpl_logs
	echo -e "\tDPNI_OPTIONS = "$DPNI_OPTIONS >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs

}

#/* Function, to intialize the DPCON related parameters
#*/
get_dpcon_parameters() {
	if [[ "$DPCON_COUNT" ]]
	then
		if [[ $DPCON_COUNT -lt 3 ]]
		then
			echo -e "\tDPCON_COUNT value should be greater than 2" >> dynamic_dpl_logs
			echo -e $RED"\tDPCON_COUNT value should be greater than 2"$NC
			return 1;
		fi

	else
		DPCON_COUNT=5
	fi
	if [[ -z "$DPCON_PRIORITIES" ]]
	then
		DPCON_PRIORITIES=8
	fi
	echo "DPCON parameters :-->" >> dynamic_dpl_logs
	echo -e "\tDPCON_PRIORITIES	= "$DPCON_PRIORITIES >> dynamic_dpl_logs
	echo -e "\tDPCON_COUNT		= "$DPCON_COUNT >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs
}

#/* Function, to intialize the DPBP related parameters
#*/
get_dpbp_parameters() {
	if [[ -z "$DPBP_COUNT" ]]
	then
		DPBP_COUNT=4
	fi
	echo "DPBP parameters :-->" >> dynamic_dpl_logs
	echo -e "\tDPBP_COUNT = "$DPBP_COUNT >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs
}

#/* Function, to intialize the DPSECI related parameters
#*/
get_dpseci_parameters() {
	if [[ -z "$DPSECI_QUEUES" ]]
	then
		DPSECI_QUEUES=8
	fi
	if [[ -z "$DPSECI_PRIORITIES" ]]
	then
		DPSECI_PRIORITIES="2,2,2,2,2,2,2,2"
	fi
	echo "DPSECI parameters :-->" >> dynamic_dpl_logs
	echo -e "\tDPSECI_QUEUES = "$DPSECI_QUEUES >> dynamic_dpl_logs
	echo -e "\tDPSECI_PRIORITIES = "$DPSECI_PRIORITIES >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs
}

#/* Function, to intialize the DPIO related parameters
#*/
get_dpio_parameters() {
	if [[ -z "$DPIO_COUNT" ]]
	then
		DPIO_COUNT=10
	fi
	if [[ -z "$DPIO_PRIORITIES" ]]
	then
		DPIO_PRIORITIES=8
	fi
	echo "DPIO parameters :-->" >> dynamic_dpl_logs
	echo -e "\tDPIO_PRIORITIES = "$DPIO_PRIORITIES >> dynamic_dpl_logs
	echo -e "\tDPIO_COUNT = "$DPIO_COUNT >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs
}

#/* Function, to intialize the DPCI related parameters
#*/
get_dpci_parameters() {
	if [[ "$DPCI_COUNT" ]]
	then
		rem=`expr $DPCI_COUNT % 2`
		if [[ $rem -eq 1 ]]
		then
			echo -e "\tDPCI_COUNT value should be an even number" >> dynamic_dpl_logs
			echo -e $RED"\tDPCI_COUNT value should be an even number"$NC
			return 1;
		fi
	else
		DPCI_COUNT=10
	fi
	echo "DPCI parameters :-->" >> dynamic_dpl_logs
	echo -e "\tDPCI_COUNT = "$DPCI_COUNT >> dynamic_dpl_logs
}

#/* function, to create the actual MAC address from the base address
#*/
create_actual_mac() {
	last_octet=$(echo $2 | head -1 | cut -f6 -d ':')
	last_octet=$(printf "%d" 0x$last_octet)
	last_octet=$(expr $last_octet + $1)
	last_octet=$(printf "%0.2x" $last_octet)
	if [[ 0x$last_octet -gt 0xFF ]]
        then
		last_octet=$(printf "%d" 0x$last_octet)
		last_octet=`expr $last_octet - 255`
		last_octet=$(printf "%0.2x" $last_octet)
	fi
	ACTUAL_MAC=$(echo $2 | sed -e 's/..$/'$last_octet'/g')
}


#/* script's actual starting point
#*/
rm dynamic_dpl_logs > /dev/null 2>&1
rm dynamic_results > /dev/null 2>&1
unset BASE_ADDR
printf "%-21s %-21s %-25s\n" "Interface Name" "Endpoint" "Mac Address" > dynamic_results
printf "%-21s %-21s %-25s\n" "==============" "========" "==================" >> dynamic_results
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
if [[ $1 ]]
then
	echo "Available DPRCs" >> dynamic_dpl_logs
	restool dprc list >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs
	#/* Creation of DPRC*/
	export DPRC=$(restool dprc create dprc.1 --label="ODP's container" --options=DPRC_CFG_OPT_SPAWN_ALLOWED,DPRC_CFG_OPT_ALLOC_ALLOWED | head -1 | cut -f1 -d ' ')

	DPRC_LOC=/sys/bus/fsl-mc/devices/$DPRC
	echo $DPRC "Created" >> dynamic_dpl_logs

	#/*Validating the arguments*/
	echo >> dynamic_dpl_logs
	echo "Validating the arguments....." >> dynamic_dpl_logs
	num=1
	max=`expr $# + 1`
	while [[ $num != $max ]]
	do
		if [[ ${!num} == "-b" ]]
		then
			num=`expr $num + 1`
			BASE_ADDR=$(echo ${!num} | egrep "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$")
			if [[ $BASE_ADDR ]]
			then
				echo >> dynamic_dpl_logs
				echo -e '\t'$BASE_ADDR" will be used as MAC's base address" >> dynamic_dpl_logs
				num=`expr $num + 1`
			else
				echo >> dynamic_dpl_logs
				echo -e "\tInvalid MAC base address" >> dynamic_dpl_logs
				echo >> dynamic_dpl_logs
				echo
				echo -e $RED"\tInvalid MAC base address"$NC
				echo
				restool dprc destroy $DPRC >> dynamic_dpl_logs
				echo >> dynamic_dpl_logs
				[[ "${BASH_SOURCE[0]}" != $0 ]] && return || exit
			fi
			continue;
		fi
		TYPE=$(echo ${!num} | head -1 | cut -f1 -d '.')
		if [[ ${!num} != "dpni-dpni" && ${!num} != "dpni-self" && $TYPE != "dpmac" && $TYPE != "dpni" ]]
		then
			echo >> dynamic_dpl_logs
			echo -e "\tInvalid Argument \""${!num}"\"" >> dynamic_dpl_logs
			echo >> dynamic_dpl_logs
			echo
			echo -e $RED"\tInvalid Argument \""${!num}"\"" $NC
			echo
			restool dprc destroy $DPRC >> dynamic_dpl_logs
			cat script_help
			rm script_help
			echo
			[[ "${BASH_SOURCE[0]}" != $0 ]] && return || exit
		fi
		num=`expr $num + 1`
	done

	#/* Getting parameters*/
	get_dpni_parameters
	get_dpcon_parameters
	RET=$?
	if [[ $RET == 1 ]]
	then
		restool dprc destroy $DPRC >> dynamic_dpl_logs
		echo
		[[ "${BASH_SOURCE[0]}" != $0 ]] && return || exit
	fi

	get_dpbp_parameters
	get_dpseci_parameters
	get_dpio_parameters
	get_dpci_parameters
	RET=$?
	if [[ $RET == 1 ]]
	then
		restool dprc destroy $DPRC >> dynamic_dpl_logs
		echo
		[[ "${BASH_SOURCE[0]}" != $0 ]] && return || exit
	fi

	#/* Objects creation*/
	num=1
	max=`expr $# + 1`
	while [[ $num != $max ]]
	do
		echo >> dynamic_dpl_logs
		echo >> dynamic_dpl_logs
		echo "####### Parsing argument number "$num" ("${!num}") #######" >> dynamic_dpl_logs
		echo >> dynamic_dpl_logs
		MAC_OCTET2=0
		TYPE=$(echo ${!num} | head -1 | cut -f1 -d '.')
		if [[ ${!num} == "dpni-dpni" ]]
		then
			if [[ $BASE_ADDR ]]
			then
				mac_no=`expr $# + $num`
				create_actual_mac $mac_no $BASE_ADDR
			else
				ACTUAL_MAC="00:00:00:00:02:"$num
			fi
			OBJ=$(restool dpni create --mac-addr=$ACTUAL_MAC --max-senders=$MAX_SENDERS --options=$DPNI_OPTIONS --max-tcs=$MAX_TCS --max-dist-per-tc=$MAX_DIST_PER_TC --max-dist-key-size=$MAX_DIST_KEY_SIZE | head -1 | cut -f1 -d ' ')
			echo $OBJ "created with MAC addr = "$ACTUAL_MAC >> dynamic_dpl_logs
			MAC_ADDR1=$ACTUAL_MAC
			MAC_OCTET2=3
			MAC_OCTET1=$num
		elif [[ ${!num} == "dpni-self" ]]
		then
			MAC_OCTET2=4
			MAC_OCTET1=$num;
		elif [[ ${!num} == "dpni" ]]
		then
			MAC_OCTET2=5
			MAC_OCTET1=$num;
		elif [[ $TYPE == "dpni" ]]
		then
			MAC_OCTET2=6
			MAC_OCTET1=$num;
		else
			OBJ=${!num}
			MAC_OCTET1=$(echo $OBJ | head -1 | cut -f2 -d '.');
		fi
		if [[ $BASE_ADDR ]]
		then
			create_actual_mac $num $BASE_ADDR
		else
			ACTUAL_MAC="00:00:00:00:"$MAC_OCTET2":"$MAC_OCTET1
		fi
		DPNI=$(restool dpni create --mac-addr=$ACTUAL_MAC --max-senders=$MAX_SENDERS --options=$DPNI_OPTIONS --max-tcs=$MAX_TCS --max-dist-per-tc=$MAX_DIST_PER_TC --max-dist-key-size=$MAX_DIST_KEY_SIZE | head -1 | cut -f1 -d ' ')
		echo -e '\t'$DPNI "created with MAC addr = "$ACTUAL_MAC >> dynamic_dpl_logs
		export DPNI$num=$DPNI
		MAC_ADDR2=$ACTUAL_MAC
		if [[ $TYPE == "dpmac" ]]
		then
			echo -e "\tDisconnecting the" $OBJ", if already connected" >> dynamic_dpl_logs
			TEMP=$(restool dprc disconnect dprc.1 --endpoint=$OBJ > /dev/null 2>&1)
			TEMP=$(restool dprc connect dprc.1 --endpoint1=$DPNI --endpoint2=$OBJ 2>&1)
			CHECK=$(echo $TEMP | head -1 | cut -f2 -d ' ');
			if [[ $CHECK == "error:" ]]
			then
				echo -e "\tGetting error, trying to create the "$OBJ >> dynamic_dpl_logs
				OBJ_ID=$(echo $OBJ | head -1 | cut -f2 -d '.')
				TEMP=$(restool dpmac create --mac-id=$OBJ_ID 2>&1)
				CHECK=$(echo $TEMP | head -1 | cut -f2 -d ' ');
				if [[ $CHECK == "error:" ]]
				then
					echo -e "\tERROR: unable to create "$OBJ $NC >> dynamic_dpl_logs
					echo -e "\tDestroying container "$DPRC >> dynamic_dpl_logs
					echo -e $RED"\tERROR: unable to create "$OBJ $NC
					./destroy_dynamic_dpl.sh $DPRC >> dynamic_dpl_logs
					echo
					rm script_help
					[[ "${BASH_SOURCE[0]}" != $0 ]] && return || exit
				fi
				restool dprc connect dprc.1 --endpoint1=$DPNI --endpoint2=$OBJ
			fi
			MAC_ADDR1=
			echo -e '\t'$OBJ" Linked with "$DPNI >> dynamic_dpl_logs
			restool dprc sync
			TEMP=$(restool dprc assign dprc.1 --object=$DPNI --child=$DPRC --plugged=1)
			echo -e '\t'$DPNI "assigned to " $DPRC >> dynamic_dpl_logs
		elif [[ ${!num} == "dpni" ]]
		then
			restool dprc sync
			TEMP=$(restool dprc assign dprc.1 --object=$DPNI --child=$DPRC --plugged=1)
			echo -e '\t'$DPNI "assigned to " $DPRC >> dynamic_dpl_logs
			MAC_ADDR1=
			OBJ=
		elif [[ $TYPE == "dpni" ]]
		then
			echo " printing the dpni ="${!num} >> dynamic_dpl_logs
			TEMP=$(restool dprc connect dprc.1 --endpoint1=$DPNI --endpoint2=${!num})
			echo -e '\t'$DPNI" Linked with "${!num} >> dynamic_dpl_logs
			restool dprc sync
			TEMP=$(restool dprc assign dprc.1 --object=$DPNI --child=$DPRC --plugged=1)
			echo -e '\t'$DPNI "assigned to " $DPRC >> dynamic_dpl_logs
			MAC_ADDR1=
			OBJ=${!num}
		elif [[ ${!num} == "dpni-self" ]]
		then
			TEMP=$(restool dprc connect dprc.1 --endpoint1=$DPNI --endpoint2=$DPNI)
			echo -e '\t'$DPNI" Linked with "$DPNI >> dynamic_dpl_logs
			restool dprc sync
			TEMP=$(restool dprc assign dprc.1 --object=$DPNI --child=$DPRC --plugged=1)
			echo -e '\t'$DPNI "assigned to " $DPRC >> dynamic_dpl_logs
			OBJ=$DPNI
			MAC_ADDR1=$MAC_ADDR2
			unset MAC_ADDR2
		else
			TEMP=$(restool dprc connect dprc.1 --endpoint1=$DPNI --endpoint2=$OBJ)
			echo -e '\t'$OBJ" Linked with "$DPNI >> dynamic_dpl_logs
			restool dprc sync
			TEMP=$(restool dprc assign dprc.1 --object=$DPNI --child=$DPRC --plugged=1)
			echo -e '\t'$DPNI "assigned to " $DPRC >> dynamic_dpl_logs
			restool dprc sync
			TEMP=$(restool dprc assign dprc.1 --object=$OBJ --child=$DPRC --plugged=1)
			echo -e '\t'$OBJ "assigned to " $DPRC >> dynamic_dpl_logs
		fi
		if [[ $MAC_ADDR1 ]]
		then
			if [[ $MAC_ADDR2 ]]
			then
				printf "%-21s %-21s %-25s\n" $DPNI $OBJ $MAC_ADDR2 >> dynamic_results
			fi
			printf "%-21s %-21s %-25s\n" $OBJ $DPNI $MAC_ADDR1 >> dynamic_results
		elif [[ $OBJ ]]
		then
			printf "%-21s %-21s %-25s\n" $DPNI $OBJ $MAC_ADDR2 >> dynamic_results
		else
			printf "%-21s %-21s %-25s\n" $DPNI "UNCONNECTED" $MAC_ADDR2 >> dynamic_results
		fi
		OBJ=
		num=`expr $num + 1`
		if [[ ${!num} == "-b" ]]
		then
			num=`expr $num + 2`
			continue;
		fi
	done
	echo >> dynamic_dpl_logs
	echo "******* End of parsing ARGS *******" >> dynamic_dpl_logs
	echo >> dynamic_dpl_logs

	restool dprc sync
	#/* Creating a loop device */
	LOOP_IF=$(restool dpni create --mac-addr="00:00:00:11:11:11" --max-senders=$MAX_SENDERS --options=$DPNI_OPTIONS --max-tcs=$MAX_TCS --max-dist-per-tc=$MAX_DIST_PER_TC --max-dist-key-size=$MAX_DIST_KEY_SIZE | head -1 | cut -f1 -d ' ')
	restool dprc sync
	TEMP=$(restool dprc connect dprc.1 --endpoint1=$LOOP_IF --endpoint2=$LOOP_IF)
	restool dprc sync
	echo -e '\t'$LOOP_IF" Linked with "$LOOP_IF >> dynamic_dpl_logs
	TEMP=$(restool dprc assign dprc.1 --object=$LOOP_IF --child=$DPRC --plugged=1)
	echo -e '\t'$LOOP_IF"assigned to " $LOOP_IF >> dynamic_dpl_logs
	restool dprc sync
	printf "%-21s %-21s %-25s\n" $LOOP_IF $LOOP_IF "00:00:00:11:11:11" >> dynamic_results
	TEMP=$(echo $DPRC | head -1 | cut -f2 -d '.')
	eval export LOOP_IF_$TEMP=$LOOP_IF

	#/* DPMCP objects creation*/
	DPMCP=$(restool dpmcp create | head -1 | cut -f1 -d ' ')
	echo $DPMCP "Created" >> dynamic_dpl_logs
	restool dprc sync
	TEMP=$(restool dprc assign dprc.1 --object=$DPMCP --child=$DPRC --plugged=1)
	echo $DPMCP "assigned to "$DPRC >> dynamic_dpl_logs
	restool dprc sync

	#/* DPBP objects creation*/
	for i in $(seq 1 ${DPBP_COUNT}); do
		DPBP=$(restool dpbp create | head -1 | cut -f1 -d ' ')
		echo $DPBP "Created" >> dynamic_dpl_logs
		restool dprc sync
		TEMP=$(restool dprc assign dprc.1 --object=$DPBP --child=$DPRC --plugged=1)
		echo $DPBP "assigned to " $DPRC >> dynamic_dpl_logs
		restool dprc sync
	done;

	#/* DPCON objects creation*/
	for i in $(seq 1 ${DPCON_COUNT}); do
		DPCON=$(restool dpcon create --num-priorities=$DPCON_PRIORITIES | head -1 | cut -f1 -d ' ')
		echo $DPCON "Created" >> dynamic_dpl_logs
		restool dprc sync
		TEMP=$(restool dprc assign dprc.1 --object=$DPCON --child=$DPRC --plugged=1)
		echo $DPCON "assigned to " $DPRC >> dynamic_dpl_logs
		restool dprc sync
	done;

	#/* DPSECI objects creation*/
	DPSEC=$(restool dpseci create --num-queues=$DPSECI_QUEUES --priorities=$DPSECI_PRIORITIES | head -1 | cut -f1 -d ' ')
	echo $DPSEC "Created" >> dynamic_dpl_logs
	restool dprc sync
	TEMP=$(restool dprc assign dprc.1 --object=$DPSEC --child=$DPRC --plugged=1)
	echo $DPSEC "assigned to " $DPRC >> dynamic_dpl_logs
	restool dprc sync

	#/* DPIO objects creation*/
	for i in $(seq 1 ${DPIO_COUNT}); do
		DPIO=$(restool dpio create --channel-mode=DPIO_LOCAL_CHANNEL --num-priorities=$DPIO_PRIORITIES | head -1 | cut -f1 -d ' ')
		echo $DPIO "Created" >> dynamic_dpl_logs
		restool dprc sync
		TEMP=$(restool dprc assign dprc.1 --object=$DPIO --child=$DPRC --plugged=1)
		echo $DPIO "assigned to "$DPRC >> dynamic_dpl_logs
		restool dprc sync
	done;

	# Create DPCI's for software queues
	unset DPCI
	for i in $(seq 1 ${DPCI_COUNT}); do
		if [[ -z "$DPCI" ]]
		then
			DPCI=$(restool dpci create | head -1 | cut -f1 -d ' ')
			echo $DPCI "Created" >> dynamic_dpl_logs
		else
			DPCI1=$(restool dpci create | head -1 | cut -f1 -d ' ')
			echo $DPCI1 "Created" >> dynamic_dpl_logs
		fi
		restool dprc sync
		if [[ "$DPCI" && "$DPCI1" ]]
		then
			TEMP=$(restool dprc connect dprc.1 --endpoint1=$DPCI --endpoint2=$DPCI1)
			echo  $DPCI" Linked with "$DPCI1 >> dynamic_dpl_logs
			restool dprc sync
			TEMP=$(restool dprc assign dprc.1 --object=$DPCI --child=$DPRC --plugged=1)
			echo $DPCI "assigned to "$DPRC >> dynamic_dpl_logs
			restool dprc sync
			TEMP=$(restool dprc assign dprc.1 --object=$DPCI1 --child=$DPRC --plugged=1)
			echo $DPCI1 "assigned to "$DPRC >> dynamic_dpl_logs
			restool	dprc sync
			unset DPCI
			unset DPCI1
		fi
	done;

	dmesg -D
	# Mount HUGETLB Pages first
	HUGE=$(grep -E '/mnt/\<hugepages\>.*hugetlbfs' /proc/mounts)
	if [[ -z $HUGE ]]
	then
		mkdir /mnt/hugepages
		mount -t hugetlbfs none /mnt/hugepages
	else
		echo >> dynamic_dpl_logs
		echo >> dynamic_dpl_logs
		echo "Already mounted :  " $HUGE >> dynamic_dpl_logs
		echo >> dynamic_dpl_logs
	fi
	echo
	if [ -e /sys/module/vfio_iommu_type1 ];
	then
	        echo -e "\tAllow unsafe interrupts" >> dynamic_dpl_logs
	        echo 1 > /sys/module/vfio_iommu_type1/parameters/allow_unsafe_interrupts
	else
	        echo -e " Can't Run DPAA2 without VFIO support" >> dynamic_dpl_logs
	        echo -e $RED" Can't Run DPAA2 without VFIO support"$NC
		[[ "${BASH_SOURCE[0]}" != $0 ]] && return || exit
	fi
	if [ -e $DPRC_LOC ];
	then
		echo vfio-fsl-mc > /sys/bus/fsl-mc/devices/$DPRC/driver_override
		echo -e "\tBind "$DPRC" to VFIO driver" >> dynamic_dpl_logs
		echo $DPRC > /sys/bus/fsl-mc/drivers/vfio-fsl-mc/bind
		echo -e "Binding to VFIO driver is done" >> dynamic_dpl_logs
	fi
	dmesg -E

	echo -e "##################### Container $GREEN $DPRC $NC is created ####################"
	echo
	echo -e "Container $DPRC have following resources :=>"
	echo
	count=$(restool dprc show $DPRC | grep -c dpbp.*)
	echo -e " * $count DPBP"
	count=$(restool dprc show $DPRC | grep -c dpcon.*)
	echo -e " * $count DPCON"
	count=$(restool dprc show $DPRC | grep -c dpseci.*)
	echo -e " * $count DPSECI"
	count=$(restool dprc show $DPRC | grep -c dpni.*)
	echo -e " * $count DPNI"
	count=$(restool dprc show $DPRC | grep -c dpio.*)
	echo -e " * $count DPIO"
	count=$(restool dprc show $DPRC | grep -c dpci.*)
	echo -e " * $count DPCI"
	echo
	echo
	unset count
	echo -e "######################### Configured Interfaces #########################"
	echo
	cat dynamic_results
	echo >> dynamic_dpl_logs
	echo -e "USE " $DPRC " FOR YOUR APPLICATIONS" >> dynamic_dpl_logs
	rm script_help
	echo

else
	echo >> dynamic_dpl_logs
	echo -e "\tArguments missing" >> dynamic_dpl_logs
	echo
	echo -e '\t'$RED"Arguments missing"$NC
	cat script_help
	rm script_help
fi
