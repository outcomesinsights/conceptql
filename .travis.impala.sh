#!/bin/bash

set -x

echo "${SEQUELIZER_URI}" | grep -i impala || exit 0

if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
  echo "Skipping tests because PRs can't access cluster"
  exit 0
fi

if [ -z "${IMPALA_CLUSTER_PRIVATE_KEY_BASE64}" ]; then
  echo "Looks like the private key for the cluster is empty?"
  exit 1
fi

eval "$(ssh-agent -s)"
timeout 10 ssh-add <(echo "${IMPALA_CLUSTER_PRIVATE_KEY_BASE64}" | base64 --decode)
ssh-add -l

ssh -o "ConnectTimeout=20" -o "StrictHostKeyChecking=no" ec2-user@ec2-52-40-86-190.us-west-2.compute.amazonaws.com ping -c 1 nonworker1.hadoop.jsaw.io || exit 0
ssh -o "ConnectTimeout=20" -o "StrictHostKeyChecking=no" -M -S my-ctrl-socket -fnNT -L 21000:nonworker1.hadoop.jsaw.io:21000 ec2-user@ec2-52-40-86-190.us-west-2.compute.amazonaws.com

SEQUELIZER_TIMEOUT=30

bundle exec ruby test/all.rb
result=$?

ssh -S my-ctrl-socket -O exit ec2-user@ec2-52-40-86-190.us-west-2.compute.amazonaws.com

set +x

exit $result
