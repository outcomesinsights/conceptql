#!/bin/bash

set -x

test -n "${USE_IMPALA}" || echo "Not using Impala..."
test -n "${USE_IMPALA}" || exit 0

eval "$(ssh-agent -s)"
ssh-add <(echo "${IMPALA_CLUSTER_PRIVATE_KEY_BASE64}" | base64 --decode)
ssh-add -l

ssh -v -o "StrictHostKeyChecking=no" ec2-user@ec2-52-40-86-190.us-west-2.compute.amazonaws.com ping -c 1 nonworker1.hadoop.jsaw.io
if [ $? -ne 0 ]; then
  echo "Cluster isn't up...skipping..."
  exit 0
fi

set +x
