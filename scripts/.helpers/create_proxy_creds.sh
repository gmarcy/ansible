
ssh ${ssh_options} root@${first_node_fqdn} podman secret rm -i proxy_credentials.yml > /dev/null
echo ""
echo "Creating the proxy cluster credentials podman secret."
fyre_ssh_key_param=$(cat ${fyre_ssh_keypair_path} | base64)
cat <<EOF | ssh ${ssh_options} root@${first_node_fqdn} podman secret create proxy_credentials.yml - > /dev/null
fyre_ssh_key:
  module: 'gmarcy.ansible.b64decode'
  param: '${fyre_ssh_key_param}'
fyre_user:
  module: 'gmarcy.ansible.b64decode'
  param: '$(echo ${FYRE_USER} | base64)'
fyre_user_email:
  module: 'gmarcy.ansible.b64decode'
  param: '$(echo ${FYRE_USER_EMAIL} | base64)'
fyre_apikey:
  module: 'gmarcy.ansible.b64decode'
  param: '$(echo ${FYRE_APIKEY} | base64)'
EOF
if ssh ${ssh_options} root@${first_node_fqdn} podman secret exists proxy_credentials.yml
then
  echo ""
  echo "The podman secret for the proxy cluster credentials now exists."
else
  echo ""
  echo "Failed to create the podman secret for the proxy cluster credentials."
  exit 1
fi
