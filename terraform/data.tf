data "terraform_remote_state" "site" {
  backend = "s3"

  config = {
    bucket         = "imdevinc-tf-storage"
    region         = "us-west-1"
    dynamodb_table = "terraform-state-lock"
    key            = "site"
  }
}
