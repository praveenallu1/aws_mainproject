# Deployment guide

This guide separates one-time account bootstrapping, infrastructure delivery, and application delivery. Use a sandbox AWS account first. The examples target `ap-southeast-2`; change the Region consistently if required.

## 1. Account safety prerequisites

- Use AWS IAM Identity Center or another federated administrator role with MFA. Do not create an IAM user access key for this project.
- Confirm that the account has alternate security, billing, and operations contacts.
- Enable account-level CloudTrail, GuardDuty, Security Hub, IAM Access Analyzer, and AWS Config through the account/platform baseline. They are intentionally not duplicated in every workload stack.
- Set `alarm_email` and `monthly_budget_usd` in a local `.auto.tfvars` file so the stack creates notifications before experimentation.
- Confirm the default service quotas for VPCs, Elastic IPs, Fargate tasks, and RDS instances.

Check the active identity before every deployment:

```bash
aws sts get-caller-identity
aws configure get region
```

## 2. Bootstrap encrypted remote state

The state bootstrap is intentionally separate because a backend cannot create the bucket in which its own state is stored.

```bash
terraform -chdir=infrastructure/bootstrap init
terraform -chdir=infrastructure/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=infrastructure/bootstrap apply bootstrap.tfplan
terraform -chdir=infrastructure/bootstrap output
```

The bootstrap state is local and protects the remote-state bucket with `prevent_destroy`. Store that small bootstrap state securely or import the resources into your platform state later.

Copy the environment backend example and replace the bucket placeholder:

```bash
cp infrastructure/backend/dev.hcl.example infrastructure/backend.hcl
terraform -chdir=infrastructure init -backend-config=backend.hcl
```

`backend.hcl` is gitignored. Each environment has a unique state key, and Terraform uses the native S3 lockfile to prevent concurrent applies.

## 3. Configure development inputs

Do not edit the committed example with private information. Copy it to an automatically loaded, gitignored file and edit all placeholders there:

```bash
cp infrastructure/environments/dev.tfvars infrastructure/dev.auto.tfvars
```

Add `alarm_email`, replace `owner`, and later add the immutable `container_image` in `dev.auto.tfvars`. The committed `environments/dev.tfvars` remains a safe reference and CI fixture. The commands below rely on Terraform automatically loading your local copy.

## 4. Bootstrap the first ECR image

The ECS service needs a runnable image, while its ECR repository is created by the same stack. Resolve that one-time dependency by targeting only the repository first. Targeted applies are an exception for bootstrapping, not the normal deployment process.

```bash
terraform -chdir=infrastructure apply \
  -target=aws_ecr_repository.app \
  -target=aws_ecr_lifecycle_policy.app

ECR_URL=$(terraform -chdir=infrastructure output -raw ecr_repository_url)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region ap-southeast-2 \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.ap-southeast-2.amazonaws.com"

docker buildx build \
  --platform linux/arm64 \
  --tag "${ECR_URL}:sha-bootstrap" \
  --push app
```

Resolve the pushed digest and set it as `container_image` in your private environment tfvars:

```bash
REPOSITORY_NAME=${ECR_URL#*/}
IMAGE_DIGEST=$(aws ecr describe-images \
  --repository-name "$REPOSITORY_NAME" \
  --image-ids imageTag=sha-bootstrap \
  --query 'imageDetails[0].imageDigest' \
  --output text)
echo "${ECR_URL}@${IMAGE_DIGEST}"
```

Production inputs should always use `repository@sha256:digest`, not a mutable tag.

## 5. Review and apply the workload

```bash
terraform -chdir=infrastructure fmt -check -recursive
terraform -chdir=infrastructure validate
terraform -chdir=infrastructure plan \
  -var="container_image=${ECR_URL}@${IMAGE_DIGEST}" \
  -out=dev.tfplan
terraform -chdir=infrastructure show dev.tfplan
terraform -chdir=infrastructure apply dev.tfplan
```

Never approve a plan that unexpectedly replaces the VPC, database, KMS key, or log bucket. Investigate the diff first.

## 6. Apply the initial database migration

The normal GitHub application workflow runs migrations as a one-off Fargate task before updating the service. For the initial local deployment, obtain the service network configuration and run `node src/migrate.js` with a task override, or configure GitHub and invoke `Deploy application` once.

After migration:

```bash
APP_URL=$(terraform -chdir=infrastructure output -raw application_url)
./scripts/smoke-test.sh "$APP_URL"
curl -X POST "$APP_URL/api/v1/tasks" \
  -H 'content-type: application/json' \
  -d '{"title":"validate production platform"}'
curl "$APP_URL/api/v1/tasks"
```

## 7. Configure GitHub OIDC

1. Create GitHub Environments named `dev` and `prod`; require reviewers for `prod`.
2. In the environment tfvars, set `github_repository`, `create_github_deploy_role = true`, and create the account-wide OIDC provider once.
3. Apply the infrastructure and save the `github_app_deploy_role_arn` output as environment variable `AWS_APP_DEPLOY_ROLE_ARN` in GitHub.
4. Add `AWS_REGION`, `PROJECT_NAME`, and the initial immutable digest as `CONTAINER_IMAGE` environment variables. Terraform needs the bootstrap digest when it first creates or ever recreates the service; normal application revisions are owned by the application workflow.
5. A separate Terraform delivery role is an account/platform control. Store its ARN as `AWS_TERRAFORM_ROLE_ARN` and the state bucket as `TF_STATE_BUCKET`. Attach a permissions boundary and refine permissions with IAM Access Analyzer after observing a successful deployment.

The trust policy only accepts the exact repository and GitHub Environment subject. The workflows request short-lived credentials and never need AWS access-key secrets.

Terraform intentionally ignores subsequent `task_definition` changes on the ECS service. This prevents infrastructure delivery from undoing application releases; the application pipeline owns service revisions, while Terraform continues to own the cluster, service settings, roles, networking, and initial task definition.

## 8. Production promotion

Production is a separate state and should normally be a separate AWS account. Before planning:

- Issue an ACM certificate in the workload Region and set `certificate_arn`.
- Create a Route 53 alias record for the ALB after apply.
- Set an immutable image digest already proven in development.
- Confirm the production safety check passes: three AZs, a NAT gateway per AZ, two or more tasks, Multi-AZ RDS, deletion protection, final snapshots, TLS, and non-Spot capacity.
- Require a human approval on the protected GitHub `prod` environment.
- Take/verify a database snapshot and record a rollback owner.

## 9. Teardown

For development only, preserve any evidence and then destroy the workload:

```bash
terraform -chdir=infrastructure plan \
  -destroy \
  -var="container_image=${ECR_URL}@${IMAGE_DIGEST}" \
  -out=destroy.tfplan
terraform -chdir=infrastructure apply destroy.tfplan
```

Confirm that NAT gateways, ALB, RDS, Elastic IPs, interface endpoints, and retained snapshots are gone. The bootstrap state bucket intentionally cannot be destroyed until `prevent_destroy` is removed in a separately reviewed change and the bucket is empty.
