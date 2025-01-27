#!/bin/bash

set -o pipefail
set -exu

cd "$(dirname "$0")/.."

_JENKINS_URL=${JENKINS_URL}

UPDATE_LIST=$( java -jar ./jar/jenkins-cli.jar -s "$_JENKINS_URL"  list-plugins | grep -e ')$' | awk '{ print $1 }' );
if [ -n "${UPDATE_LIST}" ]; then
    echo "Updating Jenkins Plugins: ${UPDATE_LIST}";
    java -jar ./jar/jenkins-cli.jar -s "$_JENKINS_URL"  install-plugin "${UPDATE_LIST}";
    java -jar ./jar/jenkins-cli.jar -s "$_JENKINS_URL"  safe-restart;
fi
