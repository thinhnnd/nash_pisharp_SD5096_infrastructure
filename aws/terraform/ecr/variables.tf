variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}