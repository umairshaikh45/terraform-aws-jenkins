#!/bin/bash

set -o pipefail
set -exu


# Assign ec2 instance to proper clusters
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config




