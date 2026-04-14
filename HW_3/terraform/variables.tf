variable "yc_token" {
  type        = string
  description = "Yandex Cloud OAuth token"
}

variable "yc_cloud_id" {
  type        = string
  description = "Yandex Cloud ID"
}

variable "yc_folder_id" {
  type        = string
  description = "Yandex Cloud Folder ID"
}

variable "yc_zone" {
  type        = string
  description = "Zone for Yandex Cloud resources (e.g. ru-central1-b)"
}

variable "yc_network_name" {
  type        = string
  description = "Name of the VPC network"
  default     = "mlops-network"
}

variable "yc_subnet_name" {
  type        = string
  description = "Name of the subnet"
  default     = "mlops-subnet"
}

variable "yc_subnet_range" {
  type        = string
  description = "CIDR block for the subnet"
  default     = "10.0.0.0/24"
}

variable "yc_route_table_name" {
  type        = string
  description = "Name of the route table"
}

variable "yc_nat_gateway_name" {
  type        = string
  description = "Name of the NAT gateway"
}

variable "yc_security_group_name" {
  type        = string
  description = "Name of the security group for Dataproc"
  default     = "mlops-dataproc-sg"
}

variable "yc_service_account_name" {
  type        = string
  description = "Name of the service account for Dataproc and storage"
  default     = "mlops-dataproc-sa"
}

variable "yc_bucket_name" {
  type        = string
  description = "Base name of the Object Storage bucket (will be suffixed with folder_id)"
  default     = "mlops-course-bucket"
}

variable "yc_dataproc_cluster_name" {
  type        = string
  description = "Name of the Dataproc cluster"
  default     = "mlops-dataproc-cluster"
}

variable "yc_dataproc_version" {
  type        = string
  description = "Dataproc version ID"
  default     = "2.1"
}

variable "public_key_path" {
  type        = string
  description = "Path to the SSH public key file"
  default     = "~/.ssh/id_rsa.pub"
}

variable "dataproc_master_resources" {
  type = object({
    resource_preset_id = string
    disk_size          = number
  })
  default = {
    resource_preset_id = "s3-c2-m8"
    disk_size          = 40
  }
}

variable "dataproc_data_resources" {
  type = object({
    resource_preset_id = string
    disk_size          = number
  })
  default = {
    resource_preset_id = "s3-c4-m16"
    disk_size          = 128
  }
}

