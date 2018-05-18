#!/bin/bash

echo "PosgreSQL? ${USING_POSTGRESQL}"
echo "Impala? ${USING_IMPALA}"

if [[ -z "${USING_IMPALA}" ]]; then
  exit 0
fi

set -x

eval "$(ssh-agent -s)"
ssh-add <(echo "${IMPALA_CLUSTER_PRIVATE_KEY_BASE64}" | base64 --decode)
ssh-add -l
ssh -vvv ec2-user@ec2-52-40-86-190.us-west-2.compute.amazonaws.com ls

set +x
