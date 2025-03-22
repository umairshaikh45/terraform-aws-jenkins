[
  {
    "name": "jenkins",
    "image": "${image}",
    "cpu": ${cpu},
    "memory": ${memory},
    "essential": true,
    "user":"jenkins",
     "environment": [
        {
          "name": "JAVA_OPTS",
          "value": "-Djenkins.install.runSetupWizard=false"
        },
        {
          "name": "JENKINS_SLAVE_AGENT_PORT",
          "value": "${jenkins_slave_agent_port}"
        },
        {
          "name": "TRY_UPGRADE_IF_NO_MARKER",
          "value": "true"
        },
         {
          "name": "JENKINS_URL",
          "value": "${jenkins_url}"
        }
      ],
    "volumesFrom": [],
    "portMappings": [
      {
        "protocol": "tcp",
        "containerPort": 8080,
        "hostPort": 8080
      },
      {
        "protocol": "tcp",
        "containerPort": ${jenkins_slave_agent_port},
        "hostPort": ${jenkins_slave_agent_port}
      }
    ],
      "mountPoints": [
      {
        "sourceVolume": "jenkins_home",
        "containerPath": "/var/jenkins_home"
      }
    ],
      "volumes":[
        {
          "name":"jenkins_home"
        }
      ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${aws_log_group}",
          "awslogs-region": "${aws_region}",
          "awslogs-stream-prefix": "${aws_prefix}"
        }
      }
  }
]
