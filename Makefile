# Secure Software Factory — End-to-End DevSecOps Pipeline
# SAMA Compliant | Zero-Trust | GitOps-Driven

.PHONY: init plan apply destroy scan-secrets test-policies generate-sbom deploy-runners fmt validate all

# ---------------------------------------------------------------------------
# Terraform Lifecycle
# ---------------------------------------------------------------------------
init:
	@echo "[INIT] Bootstrapping backend and initializing Terraform..."
	@bash scripts/bootstrap-backend.sh
	@cd terraform && terraform init -backend-config=environments/$(ENV)/backend.hcl

plan:
	@echo "[PLAN] Planning $(ENV) environment..."
	@cd terraform && terraform plan -var-file=environments/$(ENV)/$(ENV).tfvars -out=$(ENV).tfplan

apply:
	@echo "[APPLY] Applying $(ENV) environment..."
	@cd terraform && terraform apply $(ENV).tfplan

destroy:
	@echo "[DESTROY] Destroying $(ENV) environment..."
	@cd terraform && terraform destroy -var-file=environments/$(ENV)/$(ENV).tfvars

fmt:
	@echo "[FMT] Formatting Terraform..."
	@terraform fmt -recursive terraform/

validate:
	@echo "[VALIDATE] Validating Terraform..."
	@cd terraform && terraform validate

# ---------------------------------------------------------------------------
# Security Scanning
# ---------------------------------------------------------------------------
scan-secrets:
	@echo "[SECRETS] Scanning with TruffleHog..."
	@trufflehog git file://. --only-verified --fail
	@trufflehog filesystem . --only-verified --fail

test-policies:
	@echo "[POLICIES] Testing Kyverno policies..."
	@for f in kubernetes/kyverno/cluster-policies/*.yaml; do \
		name=$$(basename $$f .yaml); \
		echo "Testing $$name..."; \
		kyverno test policies/kyverno-tests/$$name; \
	done

# ---------------------------------------------------------------------------
# SBOM & Signing
# ---------------------------------------------------------------------------
generate-sbom:
	@echo "[SBOM] Generating CycloneDX SBOM..."
	@bash scripts/generate-sbom.sh

# ---------------------------------------------------------------------------
# Runner Management
# ---------------------------------------------------------------------------
deploy-runners:
	@echo "[RUNNERS] Deploying GitHub Actions self-hosted runners..."
	@kubectl apply -k kubernetes/github-runners/
	@bash scripts/rotate-runners.sh

# ---------------------------------------------------------------------------
# Pre-flight & Verification
# ---------------------------------------------------------------------------
preflight:
	@echo "[PREFLIGHT] Running pre-flight checks..."
	@bash scripts/pre-flight-checks.sh

verify:
	@echo "[VERIFY] Verifying deployment readiness..."
	@bash scripts/verify-deployment.sh

# ---------------------------------------------------------------------------
# Composite Targets
# ---------------------------------------------------------------------------
all: preflight fmt validate scan-secrets test-policies init plan apply verify
	@echo "[DONE] Secure Software Factory deployed successfully."
