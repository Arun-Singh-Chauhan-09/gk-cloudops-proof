# ============================================================================
# Example Terraform for a retail data bucket + security group.
#
# NOTE: this file intentionally contains common misconfigurations so the
# Checkov policy gate in CI has something real to catch. The "fixed" version
# lives in main_secure.tf. The point of the folder is to demonstrate that bad
# infra is *blocked before merge*, not to ship insecure infra.
# ============================================================================

provider "aws" {
  region = "eu-central-1"
}

# BAD: unencrypted, no public-access block, no versioning.
resource "aws_s3_bucket" "pos_logs" {
  bucket = "cloud4retail-pos-logs-example"
}

# BAD: security group open to the world on all ports.
resource "aws_security_group" "pos_sg" {
  name        = "pos-sg"
  description = "POS service SG"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
