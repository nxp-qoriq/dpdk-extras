#
# Copyright (c) 2017, NXP Semiconductor Inc.
# All rights reserved.
#
# 
#/* This script created  to destroy kernel dpni interface*/
TEMP_OBJ=$(ls  /sys/bus/fsl-mc/drivers/fsl_dpaa2_eth/ | grep dpni |awk 'FNR == 1 {print $1}')
TYPE=$(echo $TEMP_OBJ | cut -f1 -d '.')

while [[ ! -z $TYPE ]]
do
    echo $TEMP_OBJ > /sys/bus/fsl-mc/drivers/fsl_dpaa2_eth/unbind
	restool $TYPE destroy $TEMP_OBJ
	TEMP_OBJ=$(ls  /sys/bus/fsl-mc/drivers/fsl_dpaa2_eth/ | grep dpni |awk 'FNR == 1 {print $1}')
	TYPE=$(echo $TEMP_OBJ | cut -f1 -d '.')

done

unset DPNI_OPTIONS

echo "destroy kernel dpni interface completed"
