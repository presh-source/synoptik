# Lambda Layer Module - Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "layer_name" {
  description = "Name of the Lambda Layer"
  type        = string
}

variable "description" {
  description = "Description of the Lambda Layer"
  type        = string
  default     = ""
}

variable "source_path" {
  description = "Path to the directory containing the layer's source code (e.g., a directory with requirements.txt)"
  type        = string
}

variable "build_path" {
  description = "Path to a directory where the layer will be built"
  type        = string
}

variable "compatible_runtimes" {
  description = "A list of compatible runtimes for the layer"
  type        = list(string)
  default     = []
}

variable "license_info" {
  description = "License information for the layer"
  type        = string
  default     = "MIT"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
