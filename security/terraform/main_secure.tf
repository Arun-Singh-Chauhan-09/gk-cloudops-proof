# ============================================================================
# Hardened version of main_insecure.tf — encryption, public-access block,
# versioning, and a scoped security group. This is what passes the gate.
# ============================================================================

resource "aws_s3_bucket" "pos_logs_secure" {
  bucket = "cloud4retail-pos-logs-secure-example"
}

resource "aws_s3_bucket_versioning" "pos_logs_secure" {
  bucket = aws_s3_bucket.pos_logs_secure.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pos_logs_secure" {
  bucket = aws_s3_bucket.pos_logs_secure.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "pos_logs_secure" {
  bucket                  = aws_s3_bucket.pos_logs_secure.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Scoped SG: only the app tier CIDR, only the service port.
resource "aws_security_group" "pos_sg_secure" {
  name        = "pos-sg-secure"
  description = "POS service SG (scoped)"

  ingress {
    description = "POS API from app subnet only"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["10.20.0.0/16"]
  }

  egress {
    description = "HTTPS egress only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
