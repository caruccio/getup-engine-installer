#!/bin/bash

set -e

if [ "$TARGET_OPENSHIFT_RELEASE" == "v3.9" ]; then
    ansible-playbook $@ /openshift-ansible/playbooks/prerequisites.yml
    ansible-playbook $@ /openshift-ansible/playbooks/deploy_cluster.yml
else
    ansible-playbook $@ /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml
fi
