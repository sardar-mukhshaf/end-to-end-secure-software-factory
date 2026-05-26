# SAMA Cyber Security Framework Compliance Mapping

| SAMA Domain | Control | Project Component | Evidence |
|-------------|---------|-------------------|----------|
| 3.2 Asset Management | 3.2.1 Inventory | Dependency-Track SBOM | `sbom.cdx.json` for every build |
| 3.2 Asset Management | 3.2.2 Classification | Terraform `security_level` variable | dev=standard, staging=hardened, prod=maximum |
| 3.3 Risk Assessment | 3.3.1 Assessment | Trivy + Snyk + SonarQube findings | SARIF reports in GitHub Security tab |
| 3.4 Patch Management | 3.4.1 Timely Patching | Grafana MTTP Dashboard | Alert if MTTP > 7 days |
| 3.4 Patch Management | 3.4.2 Vulnerability Mgmt | Dependency-Track | Continuous vulnerability analysis |
| 3.5 Incident Management | 3.5.1 Detection | Falco + GuardDuty + Kyverno | Real-time alerts to PagerDuty |
| 3.5 Incident Management | 3.5.2 Response | PagerDuty + Runbooks + Lambda | Auto-isolation for critical threats |
| 3.6 Audit Logging | 3.6.1 Comprehensive Logs | CloudWatch + VPC Flow Logs | 7-year retention in S3 |
| 3.6 Audit Logging | 3.6.2 Log Protection | KMS encryption + MFA delete | `prevent_destroy` on log buckets |
| 3.7 Cryptography | 3.7.1 Encryption | KMS for all data at rest | EKS, ECR, S3, RDS, CloudWatch |
| 3.7 Cryptography | 3.7.2 Key Management | Automatic rotation, least privilege | 30-day deletion window, IRSA-only access |
| 3.8 Access Control | 3.8.1 Identity Mgmt | IRSA for every workload | No static credentials in pods |
| 3.8 Access Control | 3.8.2 Least Privilege | IAM policies, Security Groups | Explicit allow, default deny |
| 3.9 Network Security | 3.9.1 Segmentation | Private subnets, VPC endpoints | No public IPs for EKS nodes |
| 3.9 Network Security | 3.9.2 Traffic Control | Security Groups, NetworkPolicies | ALB 443 only, deny-all default |
