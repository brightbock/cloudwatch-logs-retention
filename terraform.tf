terraform {
  required_version = ">= 1.5.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.2.0"
    }
  }
}
