[
  {
    "name": "jenkins",
    "image": "${image}",
    "cpu": ${cpu},
    "memory": ${memory},
    "essential": true,
    "user":"jenkins",
    "environment": [
%{ for key, value in jenkins_environment_variables ~}
  {
    "name": "${key}",
    "value": "${value}"
  }%{ if key != keys(jenkins_environment_variables)[length(jenkins_environment_variables) - 1] },%{ endif }
%{ endfor ~}
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
        "containerPort": ${jenkins_environment_variables["JENKINS_SLAVE_AGENT_PORT"]},
        "hostPort": ${jenkins_environment_variables["JENKINS_SLAVE_AGENT_PORT"]}
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
