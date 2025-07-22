
if [ -f ${cache_dir}/creds/fyre ]
then
  . ${cache_dir}/creds/fyre
  . ${script_dir}/.helpers/check_fyre_creds.sh
else
  mkdir -p -m 700 ${cache_dir}/creds
  check_creds_result="failure"
fi

if [ "${check_creds_result}" = "failure" ]
then
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
    . ${script_dir}/.helpers/check_fyre_creds.sh
    if [ "${check_creds_result}" = "success" ]
    then
      break
    fi
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
  mkdir -p -m 700 ${cache_dir}/creds
  touch ${cache_dir}/creds/fyre
  chmod 600 ${cache_dir}/creds/fyre
  cat <<EOF > ${cache_dir}/creds/fyre
FYRE_USER="\$(echo '$(echo ${FYRE_USER} | base64)' | base64 -d)"
FYRE_USER_EMAIL="\$(echo '$(echo ${FYRE_USER_EMAIL} | base64)' | base64 -d)"
FYRE_APIKEY="\$(echo '$(echo ${FYRE_APIKEY} | base64)' | base64 -d)"
EOF
  echo "Fyre credentials have been cached in ${cache_dir}/creds/fyre"
fi
