# CLAUDE.md — open-projects-hub-infra

<!-- ai-repo-setup:generated:start -->
## Repo Structure

This is an **infrastructure-only** repository: Terraform for the Open Projects Hub
production deployment (one AWS EC2 host behind Cloudflare). See `README.md` for the
architecture, apply order, secrets and Cloudflare setup.

- **Infrastructure**: `bootstrap/` (S3 state bucket, applied by hand with local state),
  `envs/prod/` (production stack: modules, Cloudflare DNS record, budgets, SSM parameters),
  `modules/compute` (EC2, Elastic IP, security group, instance role, `user_data`),
  `modules/deploy` (SSM document that deploys an API release tag).
- **Frontend**: not applicable — the web app is hosted by Cloudflare Workers from
  `open-projects-hub-web`.
- **Backend**: not applicable — the API code and `scripts/deploy-release.sh` live in
  `open-projects-hub-api`.
- **Docs**: not applicable — `README.md` is the only documentation here; architecture and
  ADRs live in `open-projects-hub-docs`.

## Global Baseline

Machine-global baseline instructions load automatically from this machine's
`ai-engineer-setup` install (`~/.claude/AGENTS.md`, opencode's configured `instructions`,
and the Copilot workspace instructions under `~/.copilot/.github/instructions`). This file
only adds rules specific to **this** repository — it does not restate global ones.
Harness-relative paths (`instructions/`, `orchestration/`) resolve through each engineer's
installed skill or global-instruction symlink.

## Area-Specific Guidance

### Infrastructure (Terraform)

- Use the `terraform` skill for HCL, modules, providers, state, plans and IAM/security,
  and the `terraform` agent for reviews. No `instructions/stacks/*.md` file exists for
  Terraform yet (`TBD`).
- Verify with the same checks as CI (`.github/workflows/terraform.yml`, Terraform version
  in `.terraform-version`): `terraform fmt -check -recursive`, then for `bootstrap` and
  `envs/prod`: `terraform -chdir=<stack> init -backend=false -input=false` and
  `terraform -chdir=<stack> validate`. These need no cloud credentials.
- Never run `terraform plan` against the backend, `apply`, `destroy`, `import`, or any
  `aws`/Cloudflare command that reaches the real account without the user's explicit
  approval. CI never applies; applies are done by hand from a workstation.
- Treat the EC2 instance, Elastic IP, security group and SSM secrets as stateful: a plan
  that destroys or replaces them is a blocker to report, not to apply. Postgres data lives
  only on the instance volume and has no backups. Never commit a removal of
  `prevent_destroy` or `disable_api_termination` in `modules/compute`.
- Never rotate or regenerate `API_KEY_ENCRYPTION_KEY`: stored user API keys become
  undecryptable.
- Never commit `*.tfvars` (only `*.tfvars.example`), state files or plan files (`tfplan`
  holds generated secrets). Do commit `.terraform.lock.hcl` changes.
- This repository is public: do not add AWS account IDs, credit balances or dates, tokens,
  or Cloudflare credentials to committed files.
- Keep the region `us-east-2` and the manual deploy model; the account does not allow
  other EC2 regions or a GitHub OIDC role, so do not add CI apply or OIDC workflows.
- SSM parameter changes reach the host only on the next API deploy
  (`scripts/deploy-release.sh` in `open-projects-hub-api`).
- When topology, ingress or the deploy flow changes, update `README.md` here and the
  deployment docs in `open-projects-hub-docs`
  (`docs/03-architecture/ops/deployment-architecture.md`, ADR-021 to ADR-023).
<!-- ai-repo-setup:generated:end -->

<!-- ai-repo-setup:custom:start -->
<!-- Add project-specific rules below this line. Preserved across re-runs. -->
<!-- ai-repo-setup:custom:end -->
