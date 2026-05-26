# Runbook: Runtime Threat Detected by Falco

## Trigger
- Falco alerts: Crypto Mining, Reverse Shell, Privilege Escalation
- PagerDuty incident created with severity CRITICAL
- Lambda auto-response has isolated the pod

## Response Steps

1. **Acknowledge and Verify**
   - Acknowledge PagerDuty incident
   - Verify Falco alert is not a false positive:
     - Check if the process is a known maintenance script
     - Check if the connection is to a known partner API
   - If false positive: Update Falco rules and close incident

2. **Immediate Containment**
   - If Lambda did not auto-isolate: Manually apply deny-all NetworkPolicy
   - Capture pod logs: `kubectl logs <pod> -n <namespace> --previous`
   - Capture node sysdig/falco logs for the time window

3. **Investigation**
   - Check how the pod was deployed:
     - Was the image signed? (`cosign verify`)
     - Did Kyverno allow it? (check policy reports)
     - Who triggered the deployment? (GitHub Actions logs)
   - Check for lateral movement:
     - Network connections from the pod
     - Other pods scheduled around the same time
     - IAM role assumptions from the pod's IRSA

4. **Eradication**
   - Delete the compromised pod
   - If node is suspected compromised, cordon and drain:
     - `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`
   - Terminate the EC2 instance if root compromise is suspected

5. **Recovery**
   - Rebuild image from known-good source
   - Deploy through the secure pipeline
   - Verify new pod passes all runtime checks

6. **Post-Incident**
   - Preserve forensic evidence in S3
   - Update threat intelligence (new mining pool domains, reverse shell signatures)
   - If APT suspected, activate full incident response team
