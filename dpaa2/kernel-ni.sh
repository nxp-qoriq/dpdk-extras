#/*
# * Copyright (c) 2015-2016 Freescale Semiconductor, Inc. All rights reserved.
# */

# Script code is taken from the restool example scripts. This script is only
# useful for loopback_sanity_test.sh script to create the kernel interfaces.
# This script should not be used by any user.

# Name of restool script
restool="restool"
root_c="dprc.1"


# Create a DPMCP object
create_dpmcp() {
	obj=$($restool --script dpmcp create)
	if [ -z "$obj" ]; then
		echo "Error: dpmcp object was not created!"
		return 1
	fi
	$restool dprc assign "$root_c" --object="$obj" --plugged=1
}

# Create a DPIO object
create_dpio() {
	# only num_priorities=8 is supported
	obj=$($restool --script dpio create \
		--channel-mode="DPIO_LOCAL_CHANNEL" \
		--num-priorities=8)
	if [ -z "$obj" ]; then
		echo "Error: dpio object was not created!"
		return 1
	fi
	$restool dprc assign "$root_c" --object="$obj" --plugged=1
}

# Create a DPBP object
create_dpbp() {
	obj=$($restool --script dpbp create)
	if [ -z "$obj" ]; then
		echo "Error: dpbp object was not created!"
		return 1
	fi
	$restool dprc assign "$root_c" --object="$obj" --plugged=1
}

# Create a DPCON object
create_dpcon() {
	# only num_priorities=8 is supported

	obj=$($restool --script dpcon create --num-priorities=2)
	if [ -z "$obj" ]; then
		echo "Error: dpcon object was not created!"
		return 1
	fi
	$restool dprc assign "$root_c" --object="$obj" --plugged=1
}

# Connect two endpoints
# The order of the two endpoint arguments is not relevant.
connect() {
	ep1=$1
	ep2=$2

	$restool dprc connect "$root_c" --endpoint1="$ep1" --endpoint2="$ep2"
}

# Create a DPNI and its private dependencies
create_dpni() {

	# Parameter adjusting, to allow us create
	# the real number of necessary DPCONs.
	case $max_dist_per_tc in
		[0-1])
			no_of_dpcons=1
			;;
		2)
			no_of_dpcons=2
			;;
		[3-4])
			no_of_dpcons=4
			;;
		[5-8])
			no_of_dpcons=8
			;;
		*)
			return
	esac

	# Create private dependencies
	create_dpbp
	create_dpmcp
	for i in $(seq 1 ${no_of_dpcons}); do
		create_dpcon
		if [ $? -ne 0 ]; then
			break;
		fi
	done

	$restool dprc sync

	# creating dpni with default params
	dpni=$($restool --script dpni create --fs-entries=1)
	if [ -z "$dpni" ]; then
		echo "Error: dpni object was not created!"
		return 1
	fi

	# Assign the newly-created DPNI to the Linux container and plug it
	# in order to trigger the probe function.
	$restool dprc assign "$root_c" --object="$dpni" --plugged=1

	$restool dprc sync

	if [ -n "$label" ]; then
		$restool dprc set-label "$dpni" --label="$label"
	fi
}

process_addni() {
	max_dist_per_tc=8
	label=

	SYS_DPRC="/sys/bus/fsl-mc/drivers/fsl_mc_dprc"
	#Endpoint object provided as argument
	endpoint=

	# The DPNI object created for the current network interface
	dpni=

	type=$(echo $1 | head -1 | cut -f1 -d '.')
	echo $type
	if [[ $type == "dpni" ]]
	then
		endpoint=$1
	else
		echo "INVALID OPTION"
		exit 1
	fi

	#Currently, no need to create any dpio object as there are sufficient DPIOs available
	#in the dprc.1, Otherwise need to call the following command.
	#create_dpio

	# Create the DPNI object and Linux network interface
	create_dpni

	# Make a link in case there is an end point specified
	connect "$dpni" "$endpoint"

	if [ -d $SYS_DPRC/"$root_c"/"$dpni"/net/ ]; then
		ni=$(ls $SYS_DPRC/"$root_c"/"$dpni"/net/)
		echo "Created interface: $ni (object:$dpni, endpoint: $endpoint)"
	else
		echo "Network interface creation failed!"
	fi
}

process_addni $1
