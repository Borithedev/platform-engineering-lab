terraform {
  backend "s3" {
    bucket = "tf-state"
    key    = "20-k8s/terraform.tfstate"
    region = "eu-west-2"


    endpoints = {
      s3 = "http://192.168.0.153:9000"
    }

    use_path_style              = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
  }
}