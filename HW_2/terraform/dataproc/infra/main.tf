//
// Create a new IAM Service Account (SA).
//
resource "yandex_iam_service_account" "sa" {
  name        = var.yc_service_account_name
  description = "service account to manage dataproc for hw2"
}

//
// Create a new IAM Service Account IAM Member.
//
resource "yandex_resourcemanager_folder_iam_member" "sa_roles" {
  for_each = toset([
    "storage.admin",
    "dataproc.editor",
    "dataproc.agent",
    "vpc.user",
  ])
  folder_id          = var.yc_folder_id
  role               = each.key
  member             = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

//
// Create a new IAM Service Account Static Access SKey.
//
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

# resource "null_resource" "delay_after_all_iam" {
#   triggers = {
#     all_roles_complete = join(",", [
#       yandex_iam_service_account.sa.id,
#       yandex_iam_service_account_static_access_key.sa-static-key.access_key,
#     ])
#   }
  
#   provisioner "local-exec" {
#     command = "echo 'Waiting 20 seconds for IAM propagation...' && sleep 20"
#   }
  
#   depends_on = [
#     yandex_iam_service_account.sa,
#     yandex_iam_service_account_static_access_key.sa-static-key,
#     yandex_resourcemanager_folder_iam_member.sa-role,
#   ]
# }

// Auxiliary resources for Compute Instance
resource "yandex_vpc_network" "network" {
  name = var.yc_network_name
}

resource "yandex_vpc_subnet" "subnet" {
  name           = var.yc_subnet_name
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [var.yc_subnet_range]
  route_table_id = yandex_vpc_route_table.route_table.id
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = var.yc_nat_gateway_name
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "route_table" {
  name       = var.yc_route_table_name
  network_id = yandex_vpc_network.network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

resource "yandex_vpc_security_group" "security_group" {
  name        = var.yc_security_group_name
  description = "Security group for Dataproc cluster"
  network_id  = yandex_vpc_network.network.id

  ingress {
    protocol       = "ANY"
    description    = "Allow all incoming traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "UI"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "Jupyter"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 8888
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outgoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outgoing traffic"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol          = "ANY"
    description       = "Internal"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }
}

//
// Create a new Storage Bucket. 
//

resource "yandex_storage_bucket" "sa_bucket" {
  bucket = var.yc_bucket_name
  folder_id  = var.yc_folder_id
  
  anonymous_access_flags {
    read        = true
    list        = true
    config_read = true
  }

  force_destroy = true

  # depends_on = [null_resource.delay_after_all_iam]
}

resource "yandex_dataproc_cluster" "dataproc_cluster" {
  depends_on         = [yandex_resourcemanager_folder_iam_member.sa_roles]
  bucket             = yandex_storage_bucket.sa_bucket.bucket
  description        = "Dataproc Cluster created by Terraform for course project"
  name               = var.yc_dataproc_cluster_name
  service_account_id = yandex_iam_service_account.sa.id
  zone_id            = var.yc_zone
  security_group_ids = [yandex_vpc_security_group.security_group.id]

  cluster_config {
    version_id = var.yc_dataproc_version

    hadoop {
      services = ["HDFS", "YARN", "SPARK", "MAPREDUCE"]
      ssh_public_keys = [file(var.public_key_path)]
    }

    subcluster_spec {
      name = "master"
      role = "MASTERNODE"
      resources {
        resource_preset_id = "s3-c2-m8"
        disk_type_id       = "network-hdd"
        disk_size          = 40
      }
      subnet_id        = yandex_vpc_subnet.subnet.id
      hosts_count      = 1
      assign_public_ip = true
    }

    subcluster_spec {
      name = "data"
      role = "DATANODE"
      resources {
        resource_preset_id = "s3-c4-m16"
        disk_type_id       = "network-hdd"
        disk_size          = 128
      }
      subnet_id   = yandex_vpc_subnet.subnet.id
      hosts_count = 3
    }
  }
}

