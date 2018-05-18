#!/bin/bash

env | sort
if ( env | grep USE_IMPALA ) ; then
  echo "Using Impala..."
  exit 0
fi

set -x

eval "$(ssh-agent -s)"
ssh-add <(echo "${IMPALA_CLUSTER_PRIVATE_KEY_BASE64}" | base64 --decode)
ssh-add -l
ssh -v -o "StrictHostKeyChecking=no" ec2-user@ec2-52-40-86-190.us-west-2.compute.amazonaws.com ls

set +x
