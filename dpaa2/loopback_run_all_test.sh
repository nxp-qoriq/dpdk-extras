#
# Copyright 2017 NXP.
#
# 
#/* This script  will verify all loopback test script*/
# example:source /usr/bin/dpdk-example/extras/loopback_run_all_test.sh
export ALL_TEST=1
export DPDK_PATH=/usr/bin/dpdk-example

test_no=1
not_tested=0
passed=0
failed=0
partial=0

echo "############################################## TEST CASES ###############################################" >> sanity_tested_apps
echo >> sanity_tested_apps

echo "################################################"
echo "add all dpdk script for one by one execution"


source ${DPDK_PATH}/extras/loopback_sanity_test.sh -a
source ${DPDK_PATH}/extras/loopback_ipfragment_reassembly.sh -a
source ${DPDK_PATH}/extras/loopback_ipsec_secgw.sh -a



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

unset ALL_TEST
unset passed
unset failed
unset partial
unset test_no
unset not_tested

