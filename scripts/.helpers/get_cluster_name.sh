
if [ ! -f ${cache_dir}/current_cluster_name ]
then
  echo tinyproxy-cluster > ${cache_dir}/current_cluster_name
fi
current_cluster_name=$(cat ${cache_dir}/current_cluster_name)

if [ "${FYRE_CLUSTER_NAME}" != "" ]
then
  cluster_name=${FYRE_CLUSTER_NAME}
else
  echo ""
  read -p 'Fyre proxy cluster name [default: "'"${current_cluster_name}"'"]: ' cluster_name
  if [ "${cluster_name}" = "" ]
  then
    cluster_name=${current_cluster_name}
  fi
fi
echo ${cluster_name} > ${cache_dir}/current_cluster_name

while (echo ${cluster_name} | grep -s '\.' > /dev/null)
do
  echo ""
  echo "Your Fyre proxy cluster name '${cluster_name}' contains a period which is not permitted in proxy cluster names."
  echo ""
  read -p 'Enter a different name for your proxy cluster: ' new_cluster_name
  if [ "${new_cluster_name}" = "" ]
  then
    echo ""
    echo "You need to enter a new cluster name."
  else
    cluster_name=${new_cluster_name}
    echo ${cluster_name} > ${cache_dir}/current_cluster_name
  fi
done

mkdir -p ${cache_dir}/${cluster_name}
