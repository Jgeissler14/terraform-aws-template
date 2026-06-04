# Terraform AWS Template

A starting point for a real AWS Terraform repo. It ships a clean multi
environment layout, OIDC based GitHub Actions (no long lived AWS keys), and a
promotion model where sandbox auto applies on merge and prod ships on a version
tag behind an approval gate.

The example "workload" is a `null_resource`, so the whole thing applies in any
account, costs nothing, and lets you see the pipeline work end to end before you
drop in real infrastructure.

## How deployment works

Three triggers, three behaviors:

1. **Open a PR.** `ci.yml` runs fmt, validate, and a read only `terraform plan`
   against sandbox state. It uses a read only IAM role, so a PR physically
   cannot apply or destroy anything. The plan is posted to the run summary.
2. **Merge to main.** `apply-sandbox.yml` applies to the sandbox environment
   automatically. The PR plan was the gate.
3. **Push a `v*.*.*` tag.** `apply-tag.yml` plans prod (read only), then waits
   for a reviewer to approve before it applies with the deploy role. Nothing
   reaches prod just by merging. Promotion is an explicit tag.

The security model is the plan and apply split. PR jobs assume a read only
role; only the post merge and post tag jobs can assume the deploy role, and the
OIDC trust policy binds each role to specific GitHub Environments so a PR cannot
borrow the deploy role.

## Layout

```
.
├── Makefile                     # init / plan / apply, ENV selects the env
├── scripts/
│   └── bootstrap-state-backend.sh   # optional: only if you switch to S3 state
├── terraform/
│   ├── versions.tf              # providers + local backend (per-env state file)
│   ├── variables.tf
│   ├── main.tf                  # the null_resource example workload
│   ├── outputs.tf
│   ├── backends/                # per env local state path (committed)
│   │   ├── sandbox.hcl
│   │   └── prod.hcl
│   ├── envs/                    # per env variables
│   │   ├── sandbox.tfvars
│   │   └── prod.tfvars
│   └── bootstrap/               # one time stack: OIDC provider, roles, GH envs
│       ├── main.tf
│       ├── variables.tf
│       ├── versions.tf
│       ├── backends/bootstrap.hcl.example
│       └── README.md
└── .github/workflows/
    ├── ci.yml                   # PR: fmt + validate + read only plan
    ├── apply-sandbox.yml        # merge to main: apply sandbox
    └── apply-tag.yml            # v*.*.* tag: plan + gated apply to prod
```

The backend is local. `versions.tf` has a `backend "local" {}` block and each
env passes its own state path at init time with `-backend-config=backends/<env>.hcl`
(for example `path = "../state/sandbox.tfstate"`). State lives under `./state/`,
which is gitignored. Local state needs zero AWS setup, which makes the repo easy
to clone and run. For a real team you'd switch to `backend "s3" {}` so state is
shared and locked; the bootstrap stack and the `bootstrap-state-backend.sh`
script are still here for exactly that.

## First time setup

With local state there's nothing to provision. Just init and go:

```bash
make init  ENV=sandbox
make plan  ENV=sandbox
make apply ENV=sandbox
```

The OIDC bootstrap stack (`terraform/bootstrap/`) is optional now. You only need
it when you wire up GitHub Actions to deploy, since CI needs roles to assume and,
in a real team, remote (S3) state to share across runs.

## Day to day

```bash
make init  ENV=sandbox     # writes state to ./state/sandbox.tfstate
make plan  ENV=sandbox
make apply ENV=sandbox
```

To ship to prod, tag a release:

```bash
git tag v1.0.0
git push origin v1.0.0     # opens the gated prod apply in GitHub Actions
```

## Making it real

Replace the `null_resource` in `terraform/main.tf` with actual modules (VPC,
ECS, S3, and so on). Everything else stays: the env files, the backends, the
roles, and the three workflows already give you a safe path from PR to sandbox
to a tagged, approved prod release.
