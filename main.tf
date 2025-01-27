terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.60"
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

