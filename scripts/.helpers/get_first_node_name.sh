
curl -s -k -u "${FYRE_USER}:${FYRE_APIKEY}" -H "Content-type: application/json" "https://ocpapi.svl.ibm.com/v1/clusters/${cluster_name}/include_vms" > ${cache_dir}/${cluster_name}/cluster_details_response.json
if grep -s '{"cluster":{.*"vms":\[{.*' ${cache_dir}/${cluster_name}/cluster_details_response.json > /dev/null
then
  first_node_name=$(sed -e 's;{"cluster":{.*"vms":\[{[^}]*"hostname":"\([^"]*\)".*;\1;' ${cache_dir}/${cluster_name}/cluster_details_response.json)
  first_node_ipaddr=$(sed -e 's;{"cluster":{.*"vms":\[{[^}]*"ips":\[{"ip_address":"\([^"]*\)".*;\1;' ${cache_dir}/${cluster_name}/cluster_details_response.json)
else
  echo "Cluster '${cluster_name}' does not have any VMs."
  exit 1
fi
first_node_fqdn="${first_node_name}.dev.fyre.ibm.com"
if [ ! -f ${cache_dir}/${cluster_name}/add_remove_vms_request.json ]
then
  sed -n -e 's;^.*"vm_id":\("[^"]*"\).*"vm_id":\("[^"]*"\).*;{"vm_id":[\1,\2]};p' ${cache_dir}/${cluster_name}/cluster_details_response.json > ${cache_dir}/${cluster_name}/add_remove_vms_request.json
fi
if [ ! -f ${cache_dir}/${cluster_name}/vm_ids ]
then
  echo $(sed -e 's;{.*"vm_id":\[\([^]]*\)].*;\1;' ${cache_dir}/${cluster_name}/add_remove_vms_request.json | sed -e 's;";;g' -e 's;,; ;g') > ${cache_dir}/${cluster_name}/vm_ids
fi
