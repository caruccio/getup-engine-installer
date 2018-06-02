#!/bin/bash

set -e

if [ "$TARGET_OPENSHIFT_RELEASE" == "v3.9" ]; the
    ansible-playbook $@ /usr/share/ansible/openshift-ansible/playbooks/openshift-node/scaleup.yml
else
    ansible-playbook $@ /usr/share/ansible/openshift-ansible/playbooks/byo/openshift-node/scaleup.yml
fi
