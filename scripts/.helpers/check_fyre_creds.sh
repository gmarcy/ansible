
check_creds_result="failure"
echo ""
echo "Testing Fyre API access"
curl -s -k -u "${FYRE_USER}:${FYRE_APIKEY}" -H "Content-type: application/json" "https://ocpapi.svl.ibm.com/v1/quota" > ${cache_dir}/creds/check_creds_output.json
if grep -s '^{"status":"success","details":.{"product_group_id":' ${cache_dir}/creds/check_creds_output.json > /dev/null
then
  echo "Passed"
  check_creds_result="success"
else
  echo "Failed! Response:"
  cat ${cache_dir}/creds/check_creds_output.json
fi
