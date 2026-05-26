# Runbook: Secret Leak Detected

## Trigger
- TruffleHog finds verified secret in commit history or filesystem
- AWS GuardDuty detects unauthorized credential use
- CloudTrail shows unusual API calls from known key

## Response Steps

1. **Immediate Rotation**
   - Rotate the leaked secret IMMEDIATELY — do not wait for investigation
   - For AWS keys: Deactivate in IAM Console, generate new key pair
   - For database credentials: Trigger Secrets Manager rotation Lambda
   - For API keys: Revoke in the provider console, generate new key

2. **Scope Assessment**
   - Check CloudTrail logs for all API calls using the leaked credential
   - Identify time window between leak and rotation
   - Determine if data was accessed, modified, or exfiltrated

3. **Containment**
   - If AWS key: Check for unauthorized EC2 launches, IAM changes, S3 access
   - If DB credential: Check query logs for unusual SELECT/DELETE patterns
   - If API key: Check provider logs for unauthorized requests

4. **Eradication**
   - Purge secret from git history using `git-filter-repo` or BFG Repo-Cleaner
   - Force-push cleaned history (coordinate with team)
   - Ensure secret is not present in any fork or clone

5. **Recovery**
   - Update all applications using the rotated secret
   - Verify services restart successfully with new credentials
   - Monitor for authentication errors

6. **Lessons Learned**
   - Why did TruffleHog pre-commit hook not catch it?
   - Was the secret in test data? If so, update test fixtures.
   - Review access patterns: Should this secret have existed in code at all?
