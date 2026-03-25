//
// Create a new IAM Service Account (SA).
//
resource "yandex_iam_service_account" "sa" {
  name        = var.sa_name
  description = "service account for hw2"
}

//
// Create a new IAM Service Account IAM Member.
//
resource "yandex_resourcemanager_folder_iam_member" "sa-role" {
  folder_id          = var.yc_folder_id
  role               = "storage.admin"
  member             = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

//
// Create a new IAM Service Account Static Access SKey.
//
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

resource "null_resource" "delay_after_all_iam" {
  triggers = {
    all_roles_complete = join(",", [
      yandex_iam_service_account.sa.id,
      yandex_iam_service_account_static_access_key.sa-static-key.access_key,
    ])
  }
  
  provisioner "local-exec" {
    command = "echo 'Waiting 20 seconds for IAM propagation...' && sleep 20"
  }
  
  depends_on = [
    yandex_iam_service_account.sa,
    yandex_iam_service_account_static_access_key.sa-static-key,
    yandex_resourcemanager_folder_iam_member.sa-role,
  ]
}

//
// Create a new Storage Bucket. 
//

resource "yandex_storage_bucket" "sa_bucket" {
  bucket = var.bucket_name
  folder_id  = var.yc_folder_id
  
  anonymous_access_flags {
    read         = true
  }

  depends_on = [null_resource.delay_after_all_iam]
}
