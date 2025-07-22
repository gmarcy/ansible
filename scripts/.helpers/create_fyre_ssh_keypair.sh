
fyre_ssh_config_path=$(echo ${cache_dir}/${cluster_name}/.ssh/fyre_config)
fyre_ssh_keypair_path=""
ssh_options="-q -F ${fyre_ssh_config_path}"

if [ -s ${cache_dir}/fyre_ssh_keypair_path ]
then
  fyre_ssh_keypair_path=$(cat ${cache_dir}/fyre_ssh_keypair_path)
  if [ ! -s ${fyre_ssh_keypair_path} ]
  then
    rm ${cache_dir}/fyre_ssh_keypair_path
    echo ""
    echo "Removed invalid cached Fyre SSH keypair path '${fyre_ssh_keypair_path}'."
    fyre_ssh_keypair_path=""
  fi
fi

while true
do
  if [ -s ${fyre_ssh_config_path} ]
  then
    raw_path=$(sed -n -e 's; *IdentityFile *;;p' ${fyre_ssh_config_path})
    if [ "${raw_path}" != "" -a -s $(eval "echo ${raw_path}") ]
    then
      eval_path=$(eval "echo ${raw_path}")
      if ssh-keygen -y -P "" -f ${eval_path} > /dev/null 2> /dev/null
      then
        if [ "${fyre_ssh_keypair_path}" = "" ]
        then
          fyre_ssh_keypair_path="${eval_path}"
        elif [ "${eval_path}" != "${fyre_ssh_keypair_path}" ]
        then
          fyre_ssh_keypair_path="${eval_path}"
          echo ""
          echo "Using Fyre SSH keypair path '${fyre_ssh_keypair_path}' from Fyre SSH config."
        fi
        echo ${fyre_ssh_keypair_path} > ${cache_dir}/fyre_ssh_keypair_path
        break
      else
        fyre_ssh_keypair_path=""
      fi
    fi
    rm -f ${fyre_ssh_config_path}
    echo ""
    echo "Removed invalid cached Fyre SSH config '${fyre_ssh_config_path}'."
  elif [ "${fyre_ssh_keypair_path}" != "" ]
  then
    if ssh-keygen -y -P "" -f ${fyre_ssh_keypair_path} > /dev/null 2> /dev/null
    then
      echo ${fyre_ssh_keypair_path} > ${cache_dir}/fyre_ssh_keypair_path
      break
    else
      echo ""
      echo "The ssh keypair at ${fyre_ssh_keypair_path} requires a passphase which is not supported by these scripts."
      echo "Please choose a different path or generate a new ssh key."
      fyre_ssh_keypair_path=""
    fi
  else
    if [ -s ${cache_dir}/.ssh/fyre_id_ed25519 ]
    then
      fyre_ssh_keypair_path=$(echo ${cache_dir}/.ssh/fyre_id_ed25519)
      if ssh-keygen -y -P "" -f ${fyre_ssh_keypair_path} > /dev/null 2> /dev/null
      then
        echo ${fyre_ssh_keypair_path} > ${cache_dir}/fyre_ssh_keypair_path
        break
      else
        echo ""
        echo "The ssh keypair at ${fyre_ssh_keypair_path} requires a passphase which is not supported by these scripts."
        echo "Please choose a different path or generate a new ssh key."
        fyre_ssh_keypair_path=""
      fi
    fi
    echo ""
    read -p 'Enter path to ssh key (no .pub suffix) you will use to access Fyre VMs [default: generate a new ssh key]: ' fyre_ssh_keypair_path
    if [ "${fyre_ssh_keypair_path}" = "" ]
    then
      mkdir -p -m 700 ${cache_dir}/.ssh
      ssh-keygen -q -t ed25519 -f ${cache_dir}/.ssh/fyre_id_ed25519 -N "" -C "Fyre proxy clusters for ${FYRE_USER}"
      fyre_ssh_keypair_path=$(echo ${cache_dir}/.ssh/fyre_id_ed25519)
      echo ${fyre_ssh_keypair_path} > ${cache_dir}/fyre_ssh_keypair_path
      break
    elif [ -s ${fyre_ssh_keypair_path} ]
    then
      if ssh-keygen -y -P "" -f ${fyre_ssh_keypair_path} > /dev/null 2> /dev/null
      then
        echo ${fyre_ssh_keypair_path} > ${cache_dir}/fyre_ssh_keypair_path
        break
      else
        echo ""
        echo "The ssh keypair at ${fyre_ssh_keypair_path} requires a passphase which is not supported by these scripts."
        echo "Please choose a different path or generate a new ssh key."
        fyre_ssh_keypair_path=""
      fi
    else
      echo ""
      echo "File not found: ${fyre_ssh_keypair_path}"
      fyre_ssh_keypair_path=""
    fi
  fi
done

if [ ! -s ${fyre_ssh_config_path} ]
then
  mkdir -p -m 700 ${cache_dir}/${cluster_name}/.ssh
  cat << EOF | tee ${fyre_ssh_config_path} > /dev/null
Host *.dev.fyre.ibm.com
    IdentitiesOnly yes
    IdentityFile ${fyre_ssh_keypair_path}
    PasswordAuthentication no
    ServerAliveCountMax 2
    ServerAliveInterval 300
    StrictHostKeyChecking accept-new
    UserKnownHostsFile /dev/null
EOF
fi

fyre_public_key=$(cat ${fyre_ssh_keypair_path}.pub)
