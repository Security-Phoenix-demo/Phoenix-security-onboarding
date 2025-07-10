provider "aws" {
  region                  = var.region
  access_key              = var.access_key
  secret_key              = var.secret_key
}

variable "region" {}
variable "access_key" {}
variable "secret_key" {}
variable "account_id" {
  description = "Your AWS account ID"
}

# Enable Security Hub
resource "aws_securityhub_account" "main" {}

# Enable AWS Inspector
resource "aws_inspector2_enabler" "enable" {
  account_ids = [var.account_id]
}

# Enable GuardDuty
resource "aws_guardduty_detector" "main" {
  enable = true
}

# IAM policy attachment for SecurityHub read-only
resource "aws_iam_user" "phoenix_security_reader" {
  name = "phoenix-security-reader"
}

resource "aws_iam_user_policy_attachment" "attach_policy" {
  user       = aws_iam_user.phoenix_security_reader.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_access_key" "phoenix_key" {
  user = aws_iam_user.phoenix_security_reader.name
}

output "aws_access_key_id" {
  value = aws_iam_access_key.phoenix_key.id
}

output "aws_secret_access_key" {
  value     = aws_iam_access_key.phoenix_key.secret
  sensitive = true
}