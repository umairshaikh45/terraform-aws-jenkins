terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.34.0"
    }
    docker = {
      source  = "calxus/docker"
      version = "3.0.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

