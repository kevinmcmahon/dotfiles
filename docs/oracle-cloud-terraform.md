# Oracle Cloud Terraform Stack for Claude Code VM

Terraform equivalent of Parts 2-3 of the [main setup guide](claude-code-oracle-cloud-setup.md). Provisions the Always Free ARM instance, VCN, subnet, and internet gateway on OCI.

**Repo:** [kevinmcmahon/oci-alwaysfree-tf-stack](https://github.com/kevinmcmahon/oci-alwaysfree-tf-stack)

Clone, set your compartment ID and region, and `terraform apply` — the availability domain and Ubuntu image are auto-discovered via data sources so you don't need to look up region-specific OCIDs.

---

## Prerequisites

- OCI CLI configured (`oci setup config`) or environment variables set
- Terraform >= 1.0 (or OpenTofu)
- A Pay-as-you-Go OCI account (see [Part 1 of the main guide](claude-code-oracle-cloud-setup.md#part-1-oracle-cloud-account--billing-setup))

---

## Quick Start

```bash
git clone https://github.com/kevinmcmahon/oci-alwaysfree-tf-stack.git
cd oci-alwaysfree-tf-stack

# Configure your tenancy
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your compartment_id and region

terraform init
terraform plan
terraform apply

# After apply, SSH in to continue with Part 3 of the main guide
ssh -i ~/.ssh/your-key ubuntu@$(terraform output -raw instance_public_ip)
```

---

## Configuration

Only two variables are required — everything else has sensible defaults:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `compartment_id` | Yes | — | OCID of your compartment (usually tenancy OCID) |
| `region` | Yes | — | OCI region (e.g., `us-chicago-1`) |
| `availability_domain_index` | No | `0` | Index into the list of ADs (change if your preferred AD is full) |
| `ssh_public_key` | No | `null` | SSH public key string (if null, reads from `ssh_public_key_path`) |
| `ssh_public_key_path` | No | `~/.ssh/id_ed25519.pub` | Path to SSH public key file |
| `instance_name` | No | `claude-dev` | Display name for the instance |
| `ocpus` | No | `4` | ARM OCPUs (Always Free max: 4 total) |
| `memory_in_gbs` | No | `24` | Memory in GB (Always Free max: 24 total) |
| `boot_volume_size_in_gbs` | No | `47` | Boot volume in GB (Always Free max: 200 total) |
| `assign_public_ip` | No | `true` | Public IP (needed for initial setup, disable after Tailscale) |

### Finding your values

```bash
# Compartment (tenancy OCID)
oci iam compartment list --query 'data[0]."compartment-id"' --raw-output

# List available regions
oci iam region list --query 'data[*].name' --raw-output
```

---

## Always Free Guardrails

This configuration stays within free limits by default:

| Resource | This stack uses | Always Free limit |
|----------|----------------|-------------------|
| ARM OCPUs | 4 | 4 total |
| Memory | 24 GB | 24 GB total |
| Boot volume | 47 GB | 200 GB total |
| Instances | 1 | Up to 4 ARM + 2 AMD |
| VCN | 1 | Included |

If you change the defaults (e.g., `boot_volume_size_in_gbs = 200`), make sure the total across **all** your instances stays within the limits above. Set up budget alerts as described in [Part 1.3 of the main guide](claude-code-oracle-cloud-setup.md#13-set-up-budget-alerts).

---

## Tearing Down

```bash
terraform destroy
```

This removes the instance, VCN, subnet, and gateway. Your Terraform state tracks what was created, so `destroy` is clean and complete.

---

## Notes

- After initial SSH setup and Tailscale installation (Part 3 of the main guide), set `assign_public_ip = false` and `terraform apply` again to remove the public IP.
- OCI provider authentication: uses `~/.oci/config` by default. See [OCI Terraform provider docs](https://registry.terraform.io/providers/oracle/oci/latest/docs) for alternatives (env vars, instance principal, etc.).
