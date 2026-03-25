variable "yc_zone" {
  description = "YC availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "sa_name" {
  type    = string
  default = "storage-editor"
}

variable "yc_folder_id" {
  type = string
}

variable "bucket_name" {
  type        = string
}

variable "yc_cloud_id" {
  type        = string
}

variable "yc_token" {
  type        = string
}
