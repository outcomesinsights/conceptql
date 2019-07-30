#!/usr/bin/env bash

shopt -s globstar nullglob
for j in test/**/*.json; do
  echo "${j}"
  jq . "${j}" | sponge "${j}"
done

