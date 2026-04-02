import {
  to = module.iam_oidc_provider.aws_iam_openid_connect_provider.this[0]
  id = "arn:aws:iam::891612574910:oidc-provider/token.actions.githubusercontent.com"
}

module "iam_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-oidc-provider"
  version = "6.2.1"

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
