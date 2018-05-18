#!/bin/bash

echo "${SEQUELIZER_URI}" | grep -i impala || exit 0

ssh -S my-ctrl-socket -O exit ec2-user@ec2-52-40-86-190.us-west-2.compute.amazonaws.com
