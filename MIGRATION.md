# Migration: Root → infra/ + kafka/

## State migration

The infra state moved from `ba-playground/terraform.tfstate` to `ba-playground/infra/terraform.tfstate`.

### Option A: Copy state in S3 (simplest)

```bash
aws s3 cp s3://terraform-state-237617081322/ba-playground/terraform.tfstate \
  s3://terraform-state-237617081322/ba-playground/infra/terraform.tfstate
```

Then run `terraform init` in `infra/` – it will use the copied state.

### Option B: Terraform migrate

```bash
cd infra
# Temporarily use old key to init
terraform init -reconfigure -backend-config="key=ba-playground/terraform.tfstate"
# Migrate to new key (edit provider.tf key first to ba-playground/infra/terraform.tfstate)
terraform init -migrate-state
```

## Kafka state

Kafka uses a new state file at `ba-playground/kafka/terraform.tfstate`. No migration needed if the topic was removed manually.
