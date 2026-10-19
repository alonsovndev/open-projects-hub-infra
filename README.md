# Open Projects Hub Infrastructure

> Terraform for the [Open Projects Hub](https://oph-docs.alonsovndev.com) production deployment on AWS, designed to stay inside the AWS Free Plan credits.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Part of [alonsovndev](https://github.com/alonsovndev), the open-source engineering lab by [Alonso Villanueva](https://alonsovndev.com).

**Links:** [web app](https://oph.alonsovndev.com) · [API](https://api-oph.alonsovndev.com) · [documentation](https://oph-docs.alonsovndev.com) · [open-projects-hub-api](https://github.com/alonsovndev/open-projects-hub-api) · [open-projects-hub-web](https://github.com/alonsovndev/open-projects-hub-web) · [open-projects-hub-docs](https://github.com/alonsovndev/open-projects-hub-docs)

```
Browser -> https://oph.alonsovndev.com      Cloudflare Workers (static web app, deployed from the web repo)
        -> https://api-oph.alonsovndev.com  Cloudflare (proxied DNS record, HTTPS)
             `-> EC2 t3.micro :443 (Caddy) -> /v1/* -> API :8080 -> Postgres container (data on EBS)
```

- The web app is hosted by Cloudflare Workers and is **not** part of this stack. The API lives on its own hostname, so the browser calls it cross-origin (CORS with credentials; the web build sets `VITE_API_BASE_URL`).
- Cloudflare is the only public entry point to the host: the security group accepts HTTPS only from Cloudflare's IP ranges. There is no SSH; use SSM Session Manager.
- PostgreSQL runs as a container on the same host. It has no published port and is reachable only from the API container.
- The API image is built by GitHub Actions on a release tag. The AWS account's organization policies allow EC2 only in `us-east-2` and do not allow a GitHub OIDC login, so CI cannot assume an AWS role: the deploy is started by hand with `scripts/deploy-release.sh` in the API repo (no long-lived keys anywhere).
- Design records in the docs repository: ADR-021 (single host), ADR-022 (Cloudflare edge) and ADR-023 (credits account, `us-east-2`, manual deploys); ADR-024 covers email.

## Status (2026-10-19)

- **Live:** the stack runs in the AWS account that holds the Free Plan credits, region `us-east-2`. API `v0.1.0` was deployed with `scripts/deploy-release.sh` and answers at `https://api-oph.alonsovndev.com`; sign-up from `https://oph.alonsovndev.com` works end to end (email through Resend, sending domain `send.alonsovndev.com`).
- **Not done:** the admin user is not seeded (not needed: self-registration works). Seeding is an optional step in the API repository.

## Layout

| Path | Purpose |
| --- | --- |
| `bootstrap/` | Applied by hand (local state, not committed): the S3 state bucket |
| `envs/prod/` | Production stack: wires the modules, the Cloudflare DNS record for the API, budgets, SSM parameters |
| `modules/compute` | EC2, Elastic IP, security group (HTTPS from Cloudflare ranges), instance role, bootstrap `user_data` |
| `modules/deploy` | The SSM document that deploys a release tag on the host |

CI: `.github/workflows/terraform.yml` runs `terraform fmt -check -recursive` and `terraform validate` on every pull request (Terraform 1.12.0); `.github/dependabot.yml` keeps the pinned GitHub Actions current. Nothing in CI applies infrastructure.

## Inputs and outputs (`envs/prod`)

| Variable | Default | Purpose |
| --- | --- | --- |
| `alert_email` | required | Receives AWS Budgets cost alerts |
| `cloudflare_zone_id` | required | Cloudflare zone holding the API hostname |
| `api_hostname` | required | Public API hostname, one label under the zone |
| `frontend_origin` | required | Web origin allowed by CORS and used in email links |
| `region` | `us-east-2` | AWS region |
| `instance_type` | `t3.micro` | API host size (Free Plan eligible) |
| `github_owner`, `api_repo` | `alonsovndev`, `open-projects-hub-api` | Where the deploy document downloads `deploy.sh` for a release tag |

Outputs: `api_url`, `host_public_ip`, `api_instance_id`, `ssm_parameter_prefix`, `deploy_document_name`. Two AWS Budgets are created: one on real (post-credit) charges and one on gross usage.

## Apply order

Requires Terraform >= 1.10 (CI pins 1.12.0 in `.terraform-version`), AWS credentials for the target account and the [Cloudflare setup](#cloudflare-setup) done.

1. `cd bootstrap && terraform init && terraform apply` (once per account; it must be applied before `envs/prod`, whose backend is the bucket created here). The bucket name is `ophub-tfstate-<account id>`: put it in `envs/prod/backend.tf`.
2. `cd envs/prod && cp terraform.tfvars.example terraform.tfvars` and set `alert_email`, `cloudflare_zone_id`, `api_hostname` and `frontend_origin`.
3. `export CLOUDFLARE_API_TOKEN=...` in the same shell (see the setup section), then `terraform init && terraform plan -out=tfplan`, review, then `terraform apply tfplan`. Delete `tfplan` afterwards; it contains generated secrets.

The state holds generated secrets (JWT key, DB password), so keep the state bucket private.

## Secrets

Generated by Terraform into SSM Parameter Store under `/ophub/prod/`: `SECRET_KEY`, `POSTGRES_PASSWORD`, `API_KEY_ENCRYPTION_KEY` (never rotate the last one; stored user API keys become undecryptable). Plain parameters derived from the variables: `API_HOST` (`api_hostname`), `FRONTEND_BASE_URL` and `CORS_ORIGINS` (`frontend_origin`), and `CORS_ALLOW_CREDENTIALS=true` (the browser session cookie needs credentialed CORS).

Placeholders (`N/A`) to set by hand with `aws ssm put-parameter --overwrite --type SecureString`: `SMTP_HOST`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM_ADDRESS`, `GEMINI_API_KEY`, `SENTRY_DSN`. The deploy script skips parameters still set to `N/A`, so the app sees them as unset. Values cannot contain a single quote. Changes reach the host on the next API deploy.

Without working SMTP the API cannot send sign-up verification codes, so new self-registered users cannot log in. Resend delivers to arbitrary recipients only from a verified sending domain (here `send.alonsovndev.com`). The SMTP values are `SMTP_HOST=smtp.resend.com`, `SMTP_USERNAME=resend`, `SMTP_PASSWORD=<Resend API key>` and `SMTP_FROM_ADDRESS=no-reply@<verified domain>`; the API repository's `docs/configuration/email-deliverability.md` has the DNS checklist ([ADR-024](https://oph-docs.alonsovndev.com/docs/04-decisions/adr-024-email-delivery-with-resend/)).

## Free Plan limits

The account is on the AWS Free Plan: a fixed period and a credit allowance. Access ends when the credits run out or the period ends, whichever comes first, and the account then closes unless the plan is upgraded. At about $12.85/month the period, not the credit balance, is the likely limit. The owner tracks the current balance and dates in the AWS console; they are not recorded here.

The account's organization policies deny EC2 outside `us-east-2` and make the GitHub OIDC login unusable. That is why the stack uses `us-east-2` and the deploy is started from a workstation instead of GitHub Actions. Other limits may exist; they show up as "explicit deny in a service control policy" errors.

The design costs about $12.85/month (the figure uses `us-east-1` list prices; the `us-east-2` price is TBD, not checked). The gross-usage budget makes credit burn visible.

There are no database backups by design (low-stakes review deployment): Postgres data lives only on the EC2 root volume. `prevent_destroy` and EC2 termination protection on the instance guard against accidental loss (a plan that deletes or replaces it fails); if you ever need a copy, run `pg_dump` by hand over SSM Session Manager.

## Cloudflare setup

One-time, by hand, before the first `terraform plan` of this design. It takes about 10 minutes. You need the domain already added to Cloudflare with status **Active** (here: `alonsovndev.com`). Dashboard labels move around now and then; the names below are the ones to look for.

**1. Pick the API hostname.** `api-oph.alonsovndev.com`. Keep it to **one label** under the zone: Cloudflare's free Universal certificate covers `alonsovndev.com` and `*.alonsovndev.com` only, so a name like `api.oph.alonsovndev.com` would fail the TLS handshake in the browser. The web app keeps its own hostname (`oph.alonsovndev.com`, managed by Workers); do not touch it. Do **not** create the DNS record yourself: Terraform creates it. If a record with that name already exists in the zone, delete it first or the apply fails with "record already exists".

**2. Copy the Zone ID.** Cloudflare dashboard > pick `alonsovndev.com` > **Overview** > right-hand column, section **API** > **Zone ID** > copy. It is a 32-character hex string, not a secret.

**3. Create an API token** (lets Terraform manage DNS in this zone only). Profile icon (top right) > **My Profile** > **API Tokens** > **Create Token** > template **Edit zone DNS** > **Use template**, then:
   - Permissions: **Zone > DNS > Edit** (leave the default).
   - Zone Resources: **Include > Specific zone > `alonsovndev.com`**.
   - Leave IP filtering empty (your IP and GitHub's change) and optionally set an expiry date after the review.
   - **Continue to summary > Create Token**, then copy the token. It is shown once.

Check it works (prints `"status":"active"`):

```bash
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" https://api.cloudflare.com/client/v4/user/tokens/verify
```

**4. Set the SSL/TLS mode.** Dashboard > `alonsovndev.com` > **SSL/TLS** > **Overview** > **Configure** > **Custom SSL/TLS** > choose **Full** (not "Full (strict)" and not "Flexible"). Then **SSL/TLS > Edge Certificates** > turn **Always Use HTTPS** on.
   - Why Full: Caddy presents a certificate from its own local CA. Full encrypts the leg to the host without validating that certificate. Full (strict) would show Cloudflare error 526; Flexible would cause a redirect loop.
   - Why this is acceptable here and the upgrade path: ADR-022 in the docs repository.

**5. Fill the Terraform variables.** In `envs/prod/terraform.tfvars` (git-ignored):

```hcl
alert_email        = "you@example.com"
cloudflare_zone_id = "<Zone ID from step 2>"
api_hostname       = "api-oph.alonsovndev.com"
frontend_origin    = "https://oph.alonsovndev.com"
```

**6. Export the token in the shell that runs Terraform.** Never put it in a file:

```bash
read -rs CLOUDFLARE_API_TOKEN && export CLOUDFLARE_API_TOKEN   # paste the token, press Enter
```

**7. Plan and review.** `terraform init` (it downloads the Cloudflare provider and updates `.terraform.lock.hcl`, which you commit), then `terraform plan -out=tfplan`.
   - On a fresh account everything is created (about 30 resources in `envs/prod`: the EC2 host, Elastic IP, security group with Cloudflare's ranges, SSM parameters and deploy document, budgets and the Cloudflare DNS record).
   - On an existing stack the EC2 instance, the security group, the Elastic IP and the SSM secrets must **not** appear as destroyed or replaced. If they do, stop and ask.

**8. After the apply.** Check the record is proxied: `dig +short api-oph.alonsovndev.com` must print Cloudflare addresses (104.x, 172.67.x), not the Elastic IP. Until the first API release is deployed the API hostname shows Cloudflare error **521** ("web server is down"), which is expected: no Caddy is running on the host yet.

Troubleshooting (errors Cloudflare shows in the browser):

| Code | Meaning here | Check |
| --- | --- | --- |
| 521 | Nothing answers on 443 | The API deploy has not run yet, or the Compose stack is down (`docker compose ps` in `/opt/ophub` over SSM) |
| 522 / 524 | Timeout reaching the host / host took over 100 s | Security group prefix list still has Cloudflare's ranges; host running; slow AI call |
| 525 | TLS handshake with the host failed | Caddy not up yet; `API_HOST` wrong in SSM (must equal `api_hostname`) |
| 526 | Host certificate rejected | SSL/TLS mode is Full (strict); set it to Full |
| Redirect loop | Too many redirects | SSL/TLS mode is Flexible; set it to Full |
| 403 HTML in the deploy smoke test | Cloudflare bot protection challenged the request | Turn off Bot Fight Mode for the zone or add a WAF skip rule for `api-oph`; the check expects a JSON 4xx |
| 1000-series | DNS points to a prohibited IP | The record is missing or not proxied; re-run `terraform plan` |

## First release checklist

Manual steps that no workflow does for you:

1. Finish the [Cloudflare setup](#cloudflare-setup) and `terraform apply` for `envs/prod`, then check the host's first boot over SSM Session Manager: `cloud-init status` (the setup script never re-runs). On a t3.micro it takes about six minutes.
2. Add tag protection (rulesets) for `v*` on the API repository: whoever can push a tag publishes the image the host will pull.
3. Set any SSM placeholders you need (see Secrets), in the region and account of the stack.
4. Push the API tag (`vX.Y.Z`). The `deploy` workflow builds and pushes the image. Set the GHCR package `open-projects-hub-api` to **Public** (GitHub profile > Packages > Package settings) once; the host pulls without credentials.
5. Deploy it from your workstation, with credentials for the stack's AWS account: `AWS_PROFILE=<profile> API_URL=<api_url output> scripts/deploy-release.sh vX.Y.Z` (in the API repo). It finds the host by its `ophub-prod-api` name tag, so it needs no instance id.
6. Make the web build call the API: `VITE_API_BASE_URL=https://api-oph.alonsovndev.com` in the web repo's `.env.production`, merged to the branch Cloudflare builds for production.
7. Smoke test from `https://oph.alonsovndev.com`: register an account (the verification code arrives by email), log in, reload (the session cookie must survive) and create a project.

Optional: seed an administrator without email over SSM (`ADMIN_PASSWORD` needs a letter and a digit): `cd /opt/ophub && docker compose -f compose.prod.yml --profile seed run --rm -e ADMIN_EMAIL=you@example.com -e ADMIN_PASSWORD='...' seed-admin`. This was not done for the current deployment.

Operational notes:

- Never delete and re-push a release tag: `raw.githubusercontent.com` caches files for several minutes, so a re-pushed tag can deploy stale files. Cut a new patch version instead.
- After changing `api_hostname`, `frontend_origin` or an SSM parameter, run `scripts/deploy-release.sh` again with the current tag: the host reads the SSM parameters only on deploy.
- Preview deployments of the web app run on other origins and are rejected by the API's CORS list; only `frontend_origin` can log in.
- Cloudflare must keep the record proxied (orange cloud). The security group admits only Cloudflare's ranges, so a DNS-only record is unreachable.

## Destroy

There is no destroy workflow: it needed a GitHub OIDC role, which the account's organization policies do not allow. Tear down from a workstation with credentials for the stack's account. Everything in `envs/prod` goes (the Cloudflare DNS record, the EC2 host **with its Postgres data**, SSM parameters, SSM document, budgets). There are no backups, so run `pg_dump` over SSM first if you want the data. The state bucket from `bootstrap/` stays, so `envs/prod` can be applied again later.

1. Remove the `prevent_destroy = true` line from `modules/compute/main.tf` locally (do not commit it).
2. Export `CLOUDFLARE_API_TOKEN`, then `terraform plan -destroy -out=destroy.tfplan` in `envs/prod`, review it, and `terraform apply destroy.tfplan`. The AWS provider switches off the instance's termination protection itself before terminating it.
3. Revert the local edit and check that no instance, Elastic IP or volume is left (`aws ec2 describe-instances`, `describe-addresses`, `describe-volumes`).

A previous teardown of this stack followed exactly these steps (`aws ec2 modify-instance-attribute` did not change the protection, the Terraform apply did).

## Contributing, security and license

Contribution guide, code of conduct and security policy are shared across the organization: see the [`.github` repository](https://github.com/alonsovndev/.github). For this repository, run `terraform fmt -recursive` before opening a pull request (CI fails on unformatted code) and never commit `terraform.tfvars`, state files or plan files. [MIT](LICENSE).
