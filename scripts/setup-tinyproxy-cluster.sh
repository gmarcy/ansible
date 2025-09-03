#!/usr/bin/env bash

script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

cache_dir=$(echo ~/.cache/tinyproxy-cluster)

if ! command -v curl > /dev/null
then
  echo "This script requires the 'curl' command to be available."
  exit 1
fi

mkdir -p ${cache_dir}

. ${script_dir}/.helpers/get_fyre_creds.sh

. ${script_dir}/.helpers/get_cluster_name.sh

. ${script_dir}/.helpers/create_fyre_ssh_keypair.sh

curl -s -k -u "${FYRE_USER}:${FYRE_APIKEY}" -H "Content-type: application/json" "https://ocpapi.svl.ibm.com/v1/clusters" > ${cache_dir}/${cluster_name}/show_clusters_response.json
if grep -s '^{.*"clusters":.*{.*"name":"'${cluster_name}'"' ${cache_dir}/${cluster_name}/show_clusters_response.json > /dev/null
then
  if grep -s '^{.*"clusters":.*{.*"name":"'${cluster_name}'","description":"Tinyproxy+SSH+Proxy+Host"' ${cache_dir}/${cluster_name}/show_clusters_response.json > /dev/null
  then
    echo ""
    echo "A proxy cluster already exists with the name '${cluster_name}'."
    echo "Skipping build, running post-provisioning."
  else
    echo ""
    echo "The cluster '${cluster_name}' is not a Tinyproxy SSH Proxy cluster."
    exit 1
  fi
else
  . ${script_dir}/.helpers/build_fyre_proxy.sh
fi

. ${script_dir}/.helpers/get_first_node_name.sh

echo ""
echo "Checking passwordless ssh access to Fyre proxy cluster ${cluster_name} node ${first_node_name}."

if ! ssh ${ssh_options} root@${first_node_fqdn} true
then
  echo ""
  echo "Unable to access ${first_node_name} without a password."
  exit 1
fi

if ! ssh ${ssh_options} root@${first_node_fqdn} command -v podman > /dev/null
then
  echo ""
  echo "Installing 'podman' command on ${first_node_name}."
  ssh ${ssh_options} root@${first_node_fqdn} dnf install -y podman
  if ! ssh ${ssh_options} root@${first_node_fqdn} command -v podman > /dev/null
  then
    echo ""
    echo "The install of the 'podman' command failed."
    exit 1
  fi
fi

. ${script_dir}/.helpers/create_proxy_creds.sh

echo ""
echo "Creating Fyre inventory in /root/.fyre/clusters/inventory.yml."
ssh ${ssh_options} root@${first_node_fqdn} mkdir -m 0775 -p /root/.fyre/clusters
sed -e "s/@@CLUSTER_NAME/${cluster_name}/" ${script_dir}/.helpers/inventory.yml.tmpl | \
  ssh ${ssh_options} root@${first_node_fqdn} tee /root/.fyre/clusters/inventory.yml > /dev/null

if ssh ${ssh_options} root@${first_node_fqdn} test -s /root/.fyre/clusters/setup-tinyproxy-cluster.yml
then
  echo ""
  echo "Playbook located in /root/.fyre/clusters/setup-tinyproxy-cluster.yml."
else
  echo ""
  echo "Creating playbook for provisioning proxy cluster VMs."
  cat <<EOF | ssh ${ssh_options} root@${first_node_fqdn} tee /root/.fyre/clusters/setup-tinyproxy-cluster.yml > /dev/null
---

- import_playbook: gmarcy.ansible.gather_playbook_facts
- import_playbook: gmarcy.ansible.gather_cluster_facts
- import_playbook: gmarcy.ansible.run_post_provisioning_roles
EOF
fi

echo ""
echo "Running automation to provision proxy cluster VMs."
ssh ${ssh_options} root@${first_node_fqdn} podman run --rm -i --pull newer --secret proxy_credentials.yml -v /root/.fyre/clusters:/home/runner/.kube/clusters ghcr.io/gmarcy/ansible:latest -i /home/runner/.kube/clusters/inventory.yml /home/runner/.kube/clusters/setup-tinyproxy-cluster.yml

exit 0
