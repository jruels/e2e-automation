variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "prefix" {
  description = "Prefix for bucket name"
  type        = string
  default     = "webapp"
}
