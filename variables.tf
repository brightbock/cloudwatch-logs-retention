variable "project_name" {
  type    = string
  default = "cloudwatch_logs_automatic_retention_period"
}

variable "retention_days_target" {
  type = string
}

variable "retention_days_min" {
  type = string
}

variable "retention_days_max" {
  type = string
}

variable "delete_empty_days" {
  type    = string
  default = "0"
}

variable "schedule_expression" {
  type    = string
  default = "rate(23 hours)"
}

variable "cache_ttl_seconds_region_list" {
  type    = string
  default = 604800
}

variable "seed_region" {
  type    = string
  default = ""
}

variable "discover_regions" {
  type    = bool
  default = true
}

variable "dry_run" {
  type    = bool
  default = true
}

variable "regex_match" {
  type    = string
  default = ""
}

variable "regex_exclude" {
  type    = string
  default = "^$"
}

variable "lambda_log_retention_in_days" {
  type    = string
  default = "365"
  validation {
    condition     = contains(["1", "3", "5", "7", "14", "30", "60", "90", "120", "150", "180", "365", "400", "545", "731", "1827", "3653"], var.lambda_log_retention_in_days)
    error_message = "Variable must be one of: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653."
  }
}


#### THE DEFAULTS SHOULD BE FINE BELOW HERE ####

variable "lambda_layers_python" {
  type    = list(any)
  default = []
}

variable "lambda_src_dir" {
  type    = string
  default = ""
}

variable "lambda_src_filename" {
  type    = string
  default = "lambda"
}

variable "lambda_zip_file" {
  type    = string
  default = ""
}

variable "lambda_memory_size" {
  type    = string
  default = "128"
}

variable "lambda_runtime" {
  type    = string
  default = "python3.10"
}

variable "lambda_architectures" {
  type    = set(string)
  default = ["arm64"]
}

variable "lambda_timeout" {
  type    = string
  default = "900"
}

