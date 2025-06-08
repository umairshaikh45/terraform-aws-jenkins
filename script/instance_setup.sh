#!/bin/bash

set -o pipefail
set -exu


# Assign ec2 instance to proper clusters
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config

# Configure backup cron job if enabled
if [ "${backup_enabled}" = "true" ]; then
  cat > /usr/local/bin/jenkins_backup.sh <<EOF
#!/bin/bash
set -euo pipefail
efs_dir=\$(grep -m1 'efs' /proc/mounts | awk '{print \$2}')
aws s3 sync "\${efs_dir}" s3://${backup_bucket_name} --delete
EOF
  chmod +x /usr/local/bin/jenkins_backup.sh
  echo "${backup_schedule} root /usr/local/bin/jenkins_backup.sh" > /etc/cron.d/jenkins_backup
fi

