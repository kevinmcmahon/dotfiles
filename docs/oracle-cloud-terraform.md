# Oracle Cloud Terraform Stack for Claude Code VM

Terraform equivalent of Parts 1-3 of the [main setup guide](claude-code-oracle-cloud-setup.md). Provisions the Always Free ARM instance, VCN, subnet, and internet gateway on OCI.

Clone, set your compartment ID and region, and `terraform apply` — the availability domain and Ubuntu image are auto-discovered via data sources so you don't need to look up region-specific OCIDs.

---

## Prerequisites

- OCI CLI configured (`oci setup config`) or environment variables set
- Terraform >= 1.0 (or OpenTofu)
- A Pay-as-you-Go OCI account (see [Part 1 of the main guide](claude-code-oracle-cloud-setup.md#part-1-oracle-cloud-account--billing-setup))

---

## File Structure

```
oci-claude-vm/
├── main.tf          # Provider, data sources, and all resources
├── variables.tf     # Input variables
├── outputs.tf       # Useful outputs (IP, instance OCID, etc.)
└── terraform.tfvars # Your values (gitignored — contains OCIDs)
```

---

## variables.tf

```hcl
variable "compartment_id" {
  description = "OCID of the compartment (usually your tenancy OCID for Always Free)"
  type        = string
}

variable "region" {
  description = "OCI region identifier (e.g., us-chicago-1, eu-frankfurt-1)"
  type        = string
}

variable "availability_domain_index" {
  description = "Index into the list of availability domains (0-based). Change if your preferred AD is full."
  type        = number
  default     = 0
}

variable "ssh_public_key" {
  description = "SSH public key string. If null, reads from ssh_public_key_path instead."
  type        = string
  default     = null
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file (used when ssh_public_key is null)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "instance_name" {
  description = "Display name for the compute instance"
  type        = string
  default     = "claude-dev"
}

variable "ocpus" {
  description = "Number of ARM OCPUs (Always Free max: 4 total across all instances)"
  type        = number
  default     = 4
}

variable "memory_in_gbs" {
  description = "Memory in GB (Always Free max: 24 total across all instances)"
  type        = number
  default     = 24
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume size in GB (Always Free max: 200 total across all volumes)"
  type        = number
  default     = 47
}

variable "assign_public_ip" {
  description = "Assign a public IP (needed for initial setup, can disable after Tailscale)"
  type        = bool
  default     = true
}
```

---

## main.tf

```hcl
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  region = var.region
}

# --- Data Sources (auto-discover AD + image) ---

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  image_id            = data.oci_core_images.ubuntu.images[0].id
  ssh_public_key      = var.ssh_public_key != null ? var.ssh_public_key : file(pathexpand(var.ssh_public_key_path))
}

# --- Networking ---

resource "oci_core_vcn" "claude_vcn" {
  compartment_id = var.compartment_id
  cidr_block     = "10.0.0.0/16"
  display_name   = "claude-vcn"
  dns_label      = "claudevcn"
}

resource "oci_core_internet_gateway" "claude_igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.claude_vcn.id
  display_name   = "claude-igw"
  enabled        = true
}

resource "oci_core_default_route_table" "claude_route_table" {
  manage_default_resource_id = oci_core_vcn.claude_vcn.default_route_table_id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.claude_igw.id
  }
}

resource "oci_core_subnet" "claude_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.claude_vcn.id
  cidr_block     = "10.0.0.0/24"
  display_name   = "claude-subnet"
  dns_label      = "claudesubnet"
  route_table_id = oci_core_vcn.claude_vcn.default_route_table_id
}

# --- Compute ---

resource "oci_core_instance" "claude_dev" {
  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
  display_name        = var.instance_name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
    boot_volume_vpus_per_gb = 10
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.claude_subnet.id
    assign_public_ip          = var.assign_public_ip
    assign_private_dns_record = true
    assign_ipv6ip             = false
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
  }

  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }

  is_pv_encryption_in_transit_enabled = true

  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false

    plugins_config {
      name          = "Compute Instance Monitoring"
      desired_state = "ENABLED"
    }
    plugins_config {
      name          = "Custom Logs Monitoring"
      desired_state = "ENABLED"
    }
    plugins_config {
      name          = "Cloud Guard Workload Protection"
      desired_state = "ENABLED"
    }
    plugins_config {
      name          = "Vulnerability Scanning"
      desired_state = "DISABLED"
    }
    plugins_config {
      name          = "Management Agent"
      desired_state = "DISABLED"
    }
    plugins_config {
      name          = "Bastion"
      desired_state = "DISABLED"
    }
    plugins_config {
      name          = "Block Volume Management"
      desired_state = "DISABLED"
    }
    plugins_config {
      name          = "Compute RDMA GPU Monitoring"
      desired_state = "DISABLED"
    }
    plugins_config {
      name          = "Compute HPC RDMA Auto-Configuration"
      desired_state = "DISABLED"
    }
    plugins_config {
      name          = "Compute HPC RDMA Authentication"
      desired_state = "DISABLED"
    }
  }
}
```

---

## outputs.tf

```hcl
output "instance_id" {
  description = "OCID of the compute instance"
  value       = oci_core_instance.claude_dev.id
}

output "instance_public_ip" {
  description = "Public IP (use for initial SSH, then switch to Tailscale)"
  value       = oci_core_instance.claude_dev.public_ip
}

output "instance_private_ip" {
  description = "Private IP within the VCN"
  value       = oci_core_instance.claude_dev.private_ip
}

output "image_id" {
  description = "OCID of the auto-selected Ubuntu image"
  value       = local.image_id
}

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.claude_vcn.id
}

output "subnet_id" {
  description = "OCID of the subnet"
  value       = oci_core_subnet.claude_subnet.id
}
```

---

## terraform.tfvars (example — do not commit)

```hcl
compartment_id = "ocid1.tenancy.oc1..aaaa..."
region         = "us-chicago-1"
```

Everything else has sensible defaults. The availability domain and Ubuntu image are auto-discovered via data sources. SSH key defaults to `~/.ssh/id_ed25519.pub` — override with `ssh_public_key` or `ssh_public_key_path` if needed.

### Finding your values

```bash
# Compartment (tenancy OCID)
oci iam compartment list --query 'data[0]."compartment-id"' --raw-output

# List available regions
oci iam region list --query 'data[*].name' --raw-output
```

---

## Usage

```bash
cd oci-claude-vm

# Initialize
terraform init

# Preview what will be created
terraform plan

# Apply (creates the instance + networking)
terraform apply

# After apply, SSH in to continue with Part 3 of the main guide
ssh -i ~/.ssh/your-key ubuntu@$(terraform output -raw instance_public_ip)
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
# Destroy all resources
terraform destroy
```

This removes the instance, VCN, subnet, and gateway. Your Terraform state tracks what was created, so `destroy` is clean and complete.

---

## Notes

- The original Resource Manager export is at `~/projects/oci-tf-stack/ocid1.ormstack.oc1.us-chicago-1/main.tf` for reference.
- After initial SSH setup and Tailscale installation (Part 3 of the main guide), set `assign_public_ip = false` and `terraform apply` again to remove the public IP.
- OCI provider authentication: uses `~/.oci/config` by default. See [OCI Terraform provider docs](https://registry.terraform.io/providers/oracle/oci/latest/docs) for alternatives (env vars, instance principal, etc.).
