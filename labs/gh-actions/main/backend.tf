terraform {
  backend "s3" {
    bucket = "tf-state-eks-jrs"
    key    = "dev/terraform.tfstate"
    region = "us-west-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
} 