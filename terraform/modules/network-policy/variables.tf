variable "app_namespace" {
  type = string
}

variable "app_port" {
  type = number
}

variable "db_subnet_cidr" {
  type = string
}

variable "helm_wait" {
  type        = bool
  default     = true
  description = "Whether Helm should wait for resources to be ready after install/upgrade. Set false to speed up installs in dev."
}

variable "helm_timeout" {
  type        = number
  default     = 300
  description = "Helm operation timeout in seconds (install/upgrade/uninstall)."
}

variable "helm_disable_hooks" {
  type        = bool
  default     = false
  description = "Disable Helm hooks during install/upgrade/uninstall. Useful for faster dev iteractions but may skip cleanup hooks."
}
