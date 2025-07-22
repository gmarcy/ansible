
echo ""
echo "Sending requests to build a Fyre proxy cluster named '${cluster_name}'."

for site in rtp svl
do
  site_upper=$(echo ${site} | tr '[a-z]' '[A-Z]')
  cat <<EOF | tee ${cache_dir}/${cluster_name}/build_check_request_${site}.json | curl -s -k -u "${FYRE_USER}:${FYRE_APIKEY}" -H "Content-type: application/json" -X POST --data @- "https://ocpapi.svl.ibm.com/v1/vm/" > ${cache_dir}/${cluster_name}/build_check_response_${site}.json
{
  "check_config": "y",
  "cpu": "4",
  "description": "Tinyproxy ${site_upper} SSH Proxy",
  "dns": "y",
  "hostname": [
    "${cluster_name}-${site}"
  ],
  "memory": "8",
  "os": "RedHat 9.4",
  "platform": "x",
  "product_group_id": "52",
  "public_network": "y",
  "quota_type": "product_group",
  "site": "${site}",
  "ssh_key": "${fyre_public_key}"
}
EOF
  if grep -s '{.*"status":"success".*"deployable":true' ${cache_dir}/${cluster_name}/build_check_response_${site}.json > /dev/null
  then
    echo "Proxy cluster VM '${cluster_name}-${site}' is deployable."
  else
    echo "Proxy cluster VM '${cluster_name}-${site}' is not deployable."
    sed -n -e 's;.*"details":"\([^"]*\)".*;  Details: \1.\n;p' ${cache_dir}/${cluster_name}/build_check_response_${site}.json
    sed -n -e 's;.*"errors":\[\([^]]*\)\].*;  Errors:\n    \1\n;p' ${cache_dir}/${cluster_name}/build_check_response_${site}.json | sed -e 's;,;\n    ;'
    exit 1
  fi
done

cat <<EOF | tee ${cache_dir}/${cluster_name}/build_cluster_request.json | curl -s -k -u "${FYRE_USER}:${FYRE_APIKEY}" -H "Content-type: application/json" -X POST --data @- "https://ocpapi.svl.ibm.com/v1/clusters/" > ${cache_dir}/${cluster_name}/build_cluster_response.json
{
  "name": "${cluster_name}",
  "description": "Tinyproxy+SSH+Proxy+Cluster"
}
EOF

if grep -s '{.*"status":"success".*"cluster_id":.*' ${cache_dir}/${cluster_name}/build_cluster_response.json > /dev/null
then
  echo "Proxy cluster '${cluster_name}' created, requesting VMs next."
else
  echo "Proxy cluster '${cluster_name}' not created,"
  sed -n -e 's;.*"details":"\([^"]*\)".*;  Details: \1.\n;p' ${cache_dir}/${cluster_name}/build_cluster_response.json
  exit 1
fi

for site in rtp svl
do
  site_upper=$(echo ${site} | tr '[a-z]' '[A-Z]')
  cat <<EOF | tee ${cache_dir}/${cluster_name}/build_vms_request_${site}.json | curl -s -k -u "${FYRE_USER}:${FYRE_APIKEY}" -H "Content-type: application/json" -X POST --data @- "https://ocpapi.svl.ibm.com/v1/vm/" > ${cache_dir}/${cluster_name}/build_vms_response_${site}.json
{
  "check_config": "n",
  "cpu": "4",
  "description": "Tinyproxy ${site_upper} SSH Proxy",
  "dns": "y",
  "hostname": [
    "${cluster_name}-${site}"
  ],
  "memory": "8",
  "os": "RedHat 9.4",
  "platform": "x",
  "product_group_id": "52",
  "public_network": "y",
  "quota_type": "product_group",
  "site": "${site}",
  "ssh_key": "${fyre_public_key}"
}
EOF
done

cp /dev/null ${cache_dir}/${cluster_name}/vm_ids
cp /dev/null ${cache_dir}/${cluster_name}/active_request_ids
declare -A vm_id_map
for site in rtp svl
do
  site_upper=$(echo ${site} | tr '[a-z]' '[A-Z]')
  if grep -s '{.*"status":"success".*"vm_id":.*' ${cache_dir}/${cluster_name}/build_vms_response_${site}.json > /dev/null
  then
    vm_id=$(sed -n -e 's;{.*"vm_id":"\([^"]*\)".*;\1;p' ${cache_dir}/${cluster_name}/build_vms_response_${site}.json)
    request_id=$(sed -e 's/.*"request_id":"\([^"]*\)".*/\1/' ${cache_dir}/${cluster_name}/build_vms_response_${site}.json)
    echo "${vm_id}" >> ${cache_dir}/${cluster_name}/vm_ids
    echo "${request_id}" >> ${cache_dir}/${cluster_name}/active_request_ids
    vm_id_map[${request_id}]=${vm_id}
  else
    echo "Proxy cluster '${cluster_name}' build ${site_upper} VM request failed."
    sed -n -e 's;.*"details":"\([^"]*\)".*;  Details: \1.\n;p' ${cache_dir}/${cluster_name}/build_vms_response_${site}.json
    sed -n -e 's;.*"errors":\[\([^]]*\)\].*;  Errors:\n    \1\n;p' ${cache_dir}/${cluster_name}/build_vms_response_${site}.json | sed -e 's;,;\n    ;'
    exit 1
  fi
done

vm_ids=$(cat ${cache_dir}/${cluster_name}/vm_ids)
echo "Proxy cluster '${cluster_name}' build VMs requested (vm_ids: $(echo ${vm_ids}))."
echo $(cat ${cache_dir}/${cluster_name}/vm_ids) | sed -e 's;^;{"vm_id":[";' -e 's; ;",";g' -e 's;$;"]};' > ${cache_dir}/${cluster_name}/add_remove_vms_request.json
cat ${cache_dir}/${cluster_name}/add_remove_vms_request.json | curl -s -k -u "${FYRE_USER}:${FYRE_APIKEY}" -H "Content-type: application/json" -X PUT -d @- "https://ocpapi.svl.ibm.com/v1/clusters/${cluster_name}/add_vm/" > ${cache_dir}/${cluster_name}/add_vms_response.json
if grep -s '{.*"status":"success".*"request_id":.*' ${cache_dir}/${cluster_name}/add_vms_response.json > /dev/null
then
  echo "Proxy cluster '${cluster_name}' VMs added to cluster."
else
  echo "Proxy cluster '${cluster_name}' unable to add VMs,"
  sed -n -e 's;.*"details":"\([^"]*\)".*;  Details: \1.\n;p' ${cache_dir}/${cluster_name}/add_vms_response.json
  exit 1
fi

declare -A progress_map
while true
do
  build_cluster_complete=true
  need_break="true"
  for request_id in $(cat ${cache_dir}/${cluster_name}/active_request_ids)
  do
    curl -s -k -u "${FYRE_USER}:${FYRE_APIKEY}" -H "Content-type: application/json" "https://ocpapi.svl.ibm.com/v1/vm/request/${request_id}" > ${cache_dir}/${cluster_name}/request_details.json
    request_status=$(sed -e 's/.*"status":"\([^"]*\)".*/\1/' ${cache_dir}/${cluster_name}/request_details.json)
    if [ "${request_status}" = "error" ]
    then
      if [ "${need_break}" = "true" ]
      then
        echo ""
        need_break="false"
      fi
      echo "Details:"
      cat ${cache_dir}/${cluster_name}/request_details.json
      exit 1
    fi
    request_operation=$(sed -e 's/.*"operation":"\([^"]*\)".*/\1/' ${cache_dir}/${cluster_name}/request_details.json)
    request_completion_percent=$(sed -e 's/.*"completion_percent":\([0-9]*\).*/\1/' ${cache_dir}/${cluster_name}/request_details.json)
    vm_id=${vm_id_map[${request_id}]}
    curl -s -k -u "${FYRE_USER}:${FYRE_APIKEY}" -H "Content-type: application/json" "https://ocpapi.svl.ibm.com/v1/vm/${vm_id}/status" > ${cache_dir}/${cluster_name}/vm-${vm_id}-status.json
    vm_last_os_state=$(sed -e 's/.*"last_os_state":"\([^"]*\)".*/\1/' ${cache_dir}/${cluster_name}/vm-${vm_id}-status.json)
    vm_status=$(sed -e 's/.*"status":"\([^"]*\)".*/\1/' ${cache_dir}/${cluster_name}/vm-${vm_id}-status.json)
    if [ "${vm_status}" = "in progress" ]
    then
      vm_completion_percent=$(sed -e 's/.*"completion_percent":"*\([0-9]*\)"*.*/\1/' ${cache_dir}/${cluster_name}/vm-${vm_id}-status.json)
    else
      vm_completion_percent="100"
    fi
    if [ "${request_completion_precent}" != "${progress_map[${request_id}]}" -o "${vm_completion_percent}" != "${progress_map[${vm_id}]}" ]
    then
      if [ "${need_break}" = "true" ]
      then
        echo ""
        need_break="false"
      fi
      echo "Last ${request_operation} request '${request_id}' status is '${request_status}' (${request_completion_percent}% complete)"
      echo "  VM ${vm_id} os state is '${vm_last_os_state}' (${vm_completion_percent}% complete)"
      progress_map[${request_id}]=${request_completion_precent}
      progress_map[${vm_id}]=${vm_completion_percent}
    fi
    if [ "${request_completion_percent}" != "100" -o "${vm_completion_percent}" != "100" ]
    then
      build_cluster_complete=false
    fi
  done
  if [ "${build_cluster_complete}" = "true" ]
  then
    break
  fi
  sleep 10
done
