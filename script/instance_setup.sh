#!/bin/bash

set -o pipefail
set -exu


# Assign ec2 instance to proper clusters
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config

# Configure backup cron job if enabled
if [ "${backup_enabled}" = "true" ]; then
  echo "${backup_schedule} root aws s3 sync /var/jenkins_home s3://${backup_bucket_name} --delete" > /etc/cron.d/jenkins_backup
fi

