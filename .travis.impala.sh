#!/bin/bash

set -x

echo "${SEQUELIZER_URI}" | grep -i impala || exit 0

eval "$(ssh-agent -s)"
timeout 10 ssh-add <(echo "${IMPALA_CLUSTER_PRIVATE_KEY_BASE64}" | base64 --decode)
ssh-add -l

echo "Added key..."

ssh -v -o "StrictHostKeyChecking=no" ec2-user@ec2-52-40-86-190.us-west-2.compute.amazonaws.com ping -c 1 nonworker2.hadoop.jsaw.io || exit 0
echo "nonworker is up..."

ssh -v -o "StrictHostKeyChecking=no" -M -S my-ctrl-socket -fnNT -L 21000:nonworker2.hadoop.jsaw.io:21000 ec2-user@ec2-52-40-86-190.us-west-2.compute.amazonaws.com
echo "Tunnel is up..."

bundle exec ruby test/all.rb
result=$?

ssh -S my-ctrl-socket -O exit ec2-user@ec2-52-40-86-190.us-west-2.compute.amazonaws.com

set +x

exit $result
