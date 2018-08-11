#!/bin/bash

REF_NAME=${1:-remotes/origin/release-3.10}
BUILD_BRANCH=${2:-${REF_NAME##*/}}

[ -e environment ] && . environment

set -exu


## Setup build environment
export LC_ALL=C LANG=en_US.UTF-8
yum install -y tito bsdtar golang createrepo gcc libffi-devel python-devel openssl-devel
yum update -y
go get -u github.com/openshift/imagebuilder/cmd/imagebuilder

## Download and build origin
if [ ! -d origin ]; then
  git clone https://github.com/openshift/origin
fi
cd origin

#ln -fs /home/centos/getup-engine/origin/_output/local/releases/rpms/origin-local-release.repo /etc/yum.repos.d/

BRANCH=$(git branch | awk '/^\*/ {print $2}')
if [ ${BRANCH} != ${BUILD_BRANCH} ]; then
  git checkout -b ${BUILD_BRANCH} ${REF_NAME}
fi
#echo 'echo ret=$?' >> hack/build-rpm-release.sh
make release || [ -d _output/local/releases/rpms ]
#make release-binaries

## Publish RPMS
cd _output/local/releases/rpms
aws s3 sync . s3://yum.infra.getupcloud.com/centos/7/paas/x86_64/openshift-origin/${BRANCH}/ --region us-east-1 --exclude='*.repo'

## Setup YUM to install
if ! grep getupcloud-openshift-origin /etc/yum.repos.d/getupcloud-openshift.repo; then
    cat > /etc/yum.repos.d/getupcloud-openshift.repo <<EOF
[getupcloud-openshift-origin]
baseurl = http://yum.infra.getupcloud.com/centos/7/paas/x86_64/openshift-origin/${BRANCH}/
gpgcheck = 0
name = OpenShift Origin - Getup Cloud
enabled = 1
EOF
fi
