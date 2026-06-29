# Security — policy gate & secret hygiene

## Policy-as-code gate (`terraform/` + `.github/workflows/security-ci.yml`)
`main_insecure.tf` is a deliberate fixture (unencrypted bucket, world-open
security group). CI runs **Checkov** against it to prove the gate detects real
misconfigurations; `main_secure.tf` is the hardened version that passes
(KMS encryption, public-access block, versioning, scoped SG ingress).

In a production module you'd drop `--soft-fail` so findings block the merge.

## Secret hygiene (`external-secrets.yaml`)
External Secrets Operator syncs from **AWS Secrets Manager** into Kubernetes
using IRSA (no static keys in-cluster, nothing sensitive in git). Extends the
Secrets Manager integration I've used in CI/CD pipelines previously.
