data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket = "terraform-state-237617081322"
    key    = "ba-playground/infra/terraform.tfstate"
    region = "eu-west-2"
  }
}
