module "letussenghomelab" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket = "letussenghomelab"

  versioning = {
    enabled = true
  }
}
