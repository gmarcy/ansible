
retries=0
echo ""
echo "Enter Fyre credentials"
echo ""
while [ ${retries} -le 1 ]
do
  while true
  do
    if [ "${FYRE_USER_EMAIL}" = "" ]
    then
      read -p 'Fyre email address: ' FYRE_USER_EMAIL
    else
      read -p 'Fyre email address [default: "'"${FYRE_USER_EMAIL}"'"]: ' new_value
      if [ "${new_value}" != "" ]
      then
        FYRE_USER_EMAIL="${new_value}"
      fi
    fi
    if (echo ${FYRE_USER_EMAIL} | grep -s '@' > /dev/null)
    then
      break
    else
      echo "Fyre email address must contain an '@'."
      echo ""
    fi
  done
  while true
  do
    if [ "${FYRE_USER}" = "" ]
    then
      read -p 'Fyre Username: ' FYRE_USER
    else
      read -p 'Fyre Username [default: "'"${FYRE_USER}"'"]: ' new_value
      if [ "${new_value}" != "" ]
      then
        FYRE_USER="${new_value}"
      fi
    fi
    if [ "${FYRE_USER}" = "" ]
    then
      echo "Fyre user must not be empty."
      echo ""
    elif (echo ${FYRE_USER} | grep -s '@' > /dev/null)
    then
      echo "Fyre user should not contain an '@'."
      echo ""
    else
      break
    fi
  done
  read -sp 'Fyre API Key: ' FYRE_APIKEY
  echo ""
  echo "Testing Fyre API access"
  curl -s -k -u "${FYRE_USER}:${FYRE_APIKEY}" -H "Content-type: application/json" "https://ocpapi.svl.ibm.com/v1/quota" > ${cache_dir}/check_creds_output.json
  if grep -s '^{"status":"success","details":.{"product_group_id":' ${cache_dir}/check_creds_output.json > /dev/null
  then
    echo "Passed"
    break
  fi
  echo "Failed! Response:"
  cat ${cache_dir}/check_creds_output.json
  ((retries++))
  if [ ${retries} -gt 1 ]
  then
    echo "Retry failed.  Run the script again after addressing the source of this failure."
    exit 1
  else
    echo "Enter Fyre credentials again"
    echo ""
  fi
done
