#!/bin/bash
set -e

rm -rf releases
mkdir -p releases

# Build and install the collection
rm -rf ~/.ansible/collections/ansible_collections/gmarcy/ansible
ansible-galaxy collection build -v --force --output-path releases/
ansible-galaxy collection install --force --force-with-deps releases/gmarcy-ansible-`cat galaxy.yml | shyaml get-value version`.tar.gz
cp galaxy.yml ~/.ansible/collections/ansible_collections/gmarcy/ansible/
cd ~/.ansible/collections/ansible_collections/gmarcy/ansible

export HOME=$(eval echo ~$USER)

ansible-test sanity \
    --skip-test ansible-doc \
    --skip-test validate-modules \
    --skip-test pylint \
    --skip-test shebang \
    --skip-test pep8 \
    -v --python 3.12
