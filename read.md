# Terraform AWS EC2 — Complete Reference Guide

This document explains every file, every variable, every decision point, and where to find the values you need — so you can build any EC2 instance from scratch for any OS.

---

## Table of Contents

1. [How Terraform Works — The Big Picture](#1-how-terraform-works--the-big-picture)
2. [Project File Structure](#2-project-file-structure)
3. [File-by-File Breakdown](#3-file-by-file-breakdown)
   - [providers.tf](#31-providerstf)
   - [variables.tf](#32-variablestf)
   - [terraform.tfvars](#33-terraformtfvars)
   - [main.tf](#34-maintf)
   - [outputs.tf](#35-outputstf)
4. [Variable Reference — Every Option Explained](#4-variable-reference--every-option-explained)
5. [How to Find the Right AMI for Any OS](#5-how-to-find-the-right-ami-for-any-os)
6. [How to Choose an Instance Type](#6-how-to-choose-an-instance-type)
7. [Networking — VPC, Subnets, and Security Groups](#7-networking--vpc-subnets-and-security-groups)
8. [Key Pairs — SSH and RDP Password Decryption](#8-key-pairs--ssh-and-rdp-password-decryption)
9. [Step-by-Step: Run Order](#9-step-by-step-run-order)
10. [Recipes — Ready-to-Use OS Examples](#10-recipes--ready-to-use-os-examples)
11. [Common Errors and Fixes](#11-common-errors-and-fixes)
12. [AWS CLI Cheat Sheet](#12-aws-cli-cheat-sheet)

---

## 1. How Terraform Works — The Big Picture

```
Your .tf files  →  terraform init   →  downloads AWS provider plugin
                →  terraform plan   →  shows what WILL be created (dry run)
                →  terraform apply  →  creates the real resources in AWS
                →  terraform destroy →  deletes everything it created
```

Terraform reads ALL `.tf` files in the folder together — it does not matter what you name them. The split into `providers.tf`, `variables.tf`, `main.tf`, `outputs.tf` is a convention for readability, not a requirement.

**State file (`terraform.tfstate`):**
Terraform writes a JSON file after every apply that records what it created. Never delete it manually. If you lose it, Terraform thinks nothing exists and will try to create duplicates.

---

## 2. Project File Structure

```
C:\Terraform\AWS\
│
├── providers.tf        ← Declares which cloud (AWS) and which version of Terraform to use
├── variables.tf        ← Declares all input variables and their defaults
├── terraform.tfvars    ← Your actual values — this is the only file you edit per deployment
├── main.tf             ← The actual infrastructure: AMI lookup, VPC, security group, EC2
├── outputs.tf          ← What Terraform prints after apply (IP, ID, RDP command, etc.)
├── .gitignore          ← Prevents secrets and state files from being committed to git
└── DOCUMENTATION.md    ← This file
```

**Which file do I edit for a new machine?**
- New deployment of the same type → edit only `terraform.tfvars`
- Different OS → edit the AMI filter in `main.tf` + relevant variables in `variables.tf`
- Different cloud region → change `aws_region` in `terraform.tfvars`

---

## 3. File-by-File Breakdown

### 3.1 `providers.tf`

```hcl
terraform {
  required_version = ">= 1.3.0"        # Minimum Terraform CLI version required

  required_providers {
    aws = {
      source  = "hashicorp/aws"         # Official AWS plugin published by HashiCorp
      version = "~> 5.0"               # Use any 5.x version (e.g. 5.0, 5.31, 5.99)
                                        # ~> means "compatible with" — allows minor updates
    }                                   # but not a jump to version 6.x
  }
}

provider "aws" {
  region = var.aws_region               # Reads the region from your variables
}
```

**What `terraform init` does with this file:**
Downloads the AWS provider plugin from the Terraform Registry into a `.terraform/` folder. This is why you must run `init` before anything else, and again whenever you change the provider version.

**`~>` version constraint explained:**
| Constraint | Means |
|------------|-------|
| `~> 5.0`   | >= 5.0, < 6.0 (any 5.x) |
| `~> 5.31`  | >= 5.31, < 5.32 (patch only) |
| `>= 5.0`   | 5.0 or higher with no upper limit |
| `= 5.31.0` | Exactly that version, locked |

---

### 3.2 `variables.tf`

This file **declares** variables — it defines what inputs exist, their type, description, and default value. It does NOT set the actual values you use (that is `terraform.tfvars`).

```hcl
variable "aws_region" {
  description = "..."   # Human-readable hint shown in terraform plan output
  type        = string  # Enforces that the value must be a text string
  default     = "us-east-1"  # Used if terraform.tfvars does not set a value
}
```

**Variable types available in Terraform:**
| Type | Example value |
|------|---------------|
| `string` | `"us-east-1"` |
| `number` | `50` |
| `bool`   | `true` |
| `list(string)` | `["a", "b", "c"]` |
| `map(string)` | `{key = "value"}` |

If you remove the `default` line, the variable becomes **required** — Terraform will ask you to enter it interactively if it is not in `terraform.tfvars`.

---

### 3.3 `terraform.tfvars`

This is the **only file you normally edit** per deployment. It sets values for every variable declared in `variables.tf`.

```hcl
aws_region       = "us-east-1"
instance_type    = "t3.micro"
instance_name    = "my-windows-ec2"
root_volume_size = 50
root_volume_type = "gp3"
allowed_rdp_cidr = "0.0.0.0/0"
```

**Rules:**
- String values must be in double quotes: `"us-east-1"`
- Number values have no quotes: `50`
- To comment out a line, prefix with `#`
- The variable name on the left must exactly match the name in `variables.tf`

**Multiple environment tip:**
You can create `terraform.tfvars` for dev and a separate file for prod:
```
terraform apply -var-file="prod.tfvars"
terraform apply -var-file="dev.tfvars"
```

---

### 3.4 `main.tf`

This is the core of the deployment. It has four sections:

#### Section 1 — Data source: AMI lookup
```hcl
data "aws_ami" "windows" {
  most_recent = true          # If multiple AMIs match, pick the newest one
  owners      = ["amazon"]    # Only return AMIs published by Amazon
                              # Other valid values: "self", "aws-marketplace", or a 12-digit account ID

  filter { ... }              # Narrow the search — all filters must match (AND logic)
}
```
This does NOT create anything. It runs a read-only query against AWS to find the AMI ID. The result is used later as `data.aws_ami.windows.id`.

#### Section 2 — Data source: Default VPC
```hcl
data "aws_vpc" "default" {
  default = true    # Every AWS account has one default VPC per region
}
```
Using the default VPC means zero networking setup required. For production, you would reference a custom VPC by ID instead.

#### Section 3 — Data source: Subnets
```hcl
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]   # List all subnets inside the default VPC
  }
}
```
Returns a list of subnet IDs. In `main.tf` the instance uses `tolist(...)[0]` which picks the first one. Subnets are Availability-Zone specific — e.g. `us-east-1a`, `us-east-1b`.

#### Section 4 — Security group
```hcl
resource "aws_security_group" "ec2_sg" { ... }
```
Acts as a virtual firewall. Rules are stateful — if you allow inbound RDP, the response traffic is automatically allowed outbound.

#### Section 5 — EC2 instance
```hcl
resource "aws_instance" "main" {
  ami                         = data.aws_ami.windows.id   # From the data source above
  instance_type               = var.instance_type
  subnet_id                   = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true    # Assigns a public IP so you can reach it from the internet
  key_name                    = var.key_name != "" ? var.key_name : null
  get_password_data           = var.key_name != "" ? true : false  # Windows only: fetches encrypted Admin password

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true      # Disk is deleted when instance is terminated
    encrypted             = true      # Encrypts the EBS volume with AWS KMS (free, always do this)
  }

  metadata_options {
    http_tokens   = "required"   # Forces IMDSv2 — prevents SSRF attacks on the metadata endpoint
    http_endpoint = "enabled"
  }
}
```

---

### 3.5 `outputs.tf`

Outputs print information to the terminal after `terraform apply` completes. They also allow other Terraform modules to read values from this one.

```hcl
output "rdp_connection" {
  description = "RDP connection target"
  value       = "mstsc /v:${aws_instance.main.public_ip}"  # Builds the command string dynamically
}

output "administrator_password" {
  sensitive = true    # Hides the value in terminal output — shown as (sensitive)
                      # You still retrieve it with: terraform output administrator_password
}
```

To see a sensitive output after apply:
```powershell
terraform output administrator_password
```

---

## 4. Variable Reference — Every Option Explained

### `aws_region`
**What it is:** The AWS geographic region where all resources will be created.

**How to decide:**
- Pick the region closest to your users for lowest latency
- Some instance types and AMIs are not available in all regions
- Free Tier resources must be in the same region as your account's Free Tier

**Where to find valid values:**
```powershell
aws ec2 describe-regions --query "Regions[].RegionName" --output table
```

**Common values:**
| Region | Location |
|--------|----------|
| `us-east-1` | N. Virginia (most services available here first) |
| `us-west-2` | Oregon |
| `eu-west-1` | Ireland |
| `eu-central-1` | Frankfurt |
| `ap-southeast-1` | Singapore |
| `ap-northeast-1` | Tokyo |

---

### `instance_type`
**What it is:** The combination of CPU, RAM, and network performance for your machine.

**How to decide — instance family:**
| Family | Purpose |
|--------|---------|
| `t3`, `t2` | General purpose, burstable — good for dev, small workloads |
| `m6i`, `m5` | Balanced CPU/RAM — good for most production workloads |
| `c6i`, `c5` | Compute-optimized — good for CPU-heavy apps |
| `r6i`, `r5` | Memory-optimized — good for databases, in-memory caches |
| `g4dn`, `p3` | GPU instances — machine learning, graphics rendering |

**How to decide — size suffix:**
`nano` < `micro` < `small` < `medium` < `large` < `xlarge` < `2xlarge` ...

**Free Tier eligible instances (750 hours/month, first 12 months):**
- `t2.micro` — 1 vCPU, 1 GB RAM
- `t3.micro` — 2 vCPU, 1 GB RAM *(Free Tier eligible only in regions where t3 Free Tier applies — verify in your account)*

**Where to find all types and current pricing:**
```
https://aws.amazon.com/ec2/instance-types/
https://instances.vantage.sh/   (third-party comparison tool — very useful)
```

**AWS CLI to list Free Tier eligible types:**
```powershell
aws ec2 describe-instance-types `
  --filters Name=free-tier-eligible,Values=true `
  --query "InstanceTypes[].InstanceType" `
  --output table
```

---

### `instance_name`
**What it is:** A label applied as the `Name` tag on the EC2 instance. Visible in the AWS Console.

**How to decide:** Any text you want. Best practice is to include environment and purpose:
- `prod-webserver-01`
- `dev-database`
- `test-windows-2022`

Tags do not affect behaviour — they are purely for identification and cost allocation.

---

### `root_volume_size`
**What it is:** The size of the primary disk (C:\ on Windows, / on Linux) in gigabytes.

**Minimum requirements by OS:**
| OS | Minimum | Recommended |
|----|---------|-------------|
| Amazon Linux 2023 | 8 GB | 20 GB |
| Ubuntu 22.04 | 8 GB | 20 GB |
| Windows Server 2022 | 30 GB | 50 GB |
| Windows Server 2019 | 30 GB | 50 GB |
| RHEL 9 | 10 GB | 30 GB |

**How to decide:** Take the minimum for the OS, add space for your applications and data. You can always increase this later (requires stopping the instance), but you cannot decrease it.

---

### `root_volume_type`
**What it is:** The type of EBS (Elastic Block Store) storage.

| Type | Speed | Cost | Use when |
|------|-------|------|----------|
| `gp3` | 3000 IOPS baseline, up to 16000 | Cheapest SSD | Default for everything — always use this |
| `gp2` | Scales with size, up to 16000 | More expensive than gp3 | Legacy, no reason to use |
| `io2` | Up to 64000 IOPS | Most expensive | High-performance databases |
| `st1` | HDD, high throughput | Cheap | Big data sequential reads |
| `sc1` | HDD, lowest throughput | Cheapest | Cold archival storage |

**Recommendation:** Always use `gp3`. It is cheaper than `gp2` and faster.

---

### `key_name`
**What it is:** The name of an EC2 Key Pair that already exists in your AWS account.

**On Windows:** The key pair is used to decrypt the auto-generated Administrator password. Without it, you cannot log in.

**On Linux:** The key pair is used for SSH authentication. The `.pem` file is your private key.

**Where to create one:**
1. AWS Console → EC2 → Key Pairs → Create key pair
2. Name it (this name is what you put in `key_name`)
3. Download the `.pem` file — AWS will never show it again
4. Save it to `C:\Users\YourName\.ssh\` or another safe location

**AWS CLI to list existing key pairs:**
```powershell
aws ec2 describe-key-pairs --query "KeyPairs[].KeyName" --output table
```

**Leave empty (`""`) only if:** You are testing and do not need to connect, or you plan to use AWS Systems Manager Session Manager for access instead.

---

### `allowed_rdp_cidr` / `allowed_ssh_cidr`
**What it is:** Which IP addresses are allowed to reach port 3389 (RDP) or 22 (SSH).

**Format:** CIDR notation — an IP address followed by a slash and a prefix length.

| Value | Means |
|-------|-------|
| `"0.0.0.0/0"` | Anyone on the internet (not recommended for production) |
| `"203.0.113.10/32"` | Only that exact IP address |
| `"203.0.113.0/24"` | All 256 addresses in that subnet |
| `"10.0.0.0/8"` | All private 10.x.x.x addresses |

**How to find your current public IP:**
```powershell
(Invoke-WebRequest -Uri "https://api.ipify.org").Content
```
Then use that IP with `/32` to lock RDP to only your machine:
```
allowed_rdp_cidr = "203.0.113.10/32"
```

---

## 5. How to Find the Right AMI for Any OS

An AMI (Amazon Machine Image) is a snapshot of a disk that AWS uses to boot your instance. Every OS has a different AMI ID, and IDs **change per region** and **change when patched** — never hardcode an ID.

### How the data source filter works

```hcl
data "aws_ami" "my_ami" {
  most_recent = true
  owners      = ["amazon"]        # Who published it

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]  # * is a wildcard
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
```

Every `filter` block narrows the results. All filters must match. `most_recent = true` picks the latest if multiple match.

### AMI name patterns for common OS

**Find these using the AWS CLI command shown below each one.**

#### Windows Server 2022
```hcl
owners = ["amazon"]
filter { name = "name", values = ["Windows_Server-2022-English-Full-Base-*"] }
```

#### Windows Server 2019
```hcl
owners = ["amazon"]
filter { name = "name", values = ["Windows_Server-2019-English-Full-Base-*"] }
```

#### Windows Server 2016
```hcl
owners = ["amazon"]
filter { name = "name", values = ["Windows_Server-2016-English-Full-Base-*"] }
```

#### Windows Server 2022 with SQL Server (pre-installed)
```hcl
owners = ["amazon"]
filter { name = "name", values = ["Windows_Server-2022-English-Full-SQL_2022_Standard-*"] }
```

#### Amazon Linux 2023
```hcl
owners = ["137112412989"]   # Amazon's account ID for Amazon Linux
filter { name = "name", values = ["al2023-ami-*-x86_64"] }
```

#### Amazon Linux 2 (older, still widely used)
```hcl
owners = ["amazon"]
filter { name = "name", values = ["amzn2-ami-hvm-*-x86_64-gp2"] }
```

#### Ubuntu 24.04 LTS
```hcl
owners = ["099720109477"]   # Canonical's AWS account ID
filter { name = "name", values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"] }
```

#### Ubuntu 22.04 LTS
```hcl
owners = ["099720109477"]
filter { name = "name", values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] }
```

#### Red Hat Enterprise Linux 9
```hcl
owners = ["309956199498"]   # Red Hat's AWS account ID
filter { name = "name", values = ["RHEL-9.*_HVM-*-x86_64-*"] }
```

#### Debian 12
```hcl
owners = ["136693071363"]   # Debian's AWS account ID
filter { name = "name", values = ["debian-12-amd64-*"] }
```

### How to find AMI names from the AWS CLI

```powershell
# Windows Server 2022 — list available AMI names in us-east-1
aws ec2 describe-images `
  --owners amazon `
  --filters "Name=name,Values=Windows_Server-2022-English-Full-Base-*" `
            "Name=state,Values=available" `
  --query "sort_by(Images, &CreationDate)[-1].{ID:ImageId, Name:Name, Date:CreationDate}" `
  --output table

# Ubuntu — find latest
aws ec2 describe-images `
  --owners 099720109477 `
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" `
            "Name=state,Values=available" `
  --query "sort_by(Images, &CreationDate)[-1].{ID:ImageId, Name:Name}" `
  --output table
```

### Trusted AMI owner account IDs

| Owner | Account ID |
|-------|------------|
| Amazon (Amazon Linux, Windows) | `amazon` or `137112412989` |
| Canonical (Ubuntu) | `099720109477` |
| Red Hat | `309956199498` |
| SUSE | `013907871322` |
| Debian | `136693071363` |
| Microsoft (Windows via Marketplace) | `aws-marketplace` |

**Security rule:** Only use AMIs from these trusted owners. Never use a random third-party AMI ID you found online — it could contain malware.

---

## 6. How to Choose an Instance Type

### Step 1 — Identify your OS requirement
- Windows Server requires at least **2 GB RAM** — use `t3.small` or larger for real workloads
- `t2.micro` / `t3.micro` (1 GB RAM) will run Windows but will be very slow under any real load

### Step 2 — Identify your workload
```
Light (dev, test, low traffic)  → t3.micro, t3.small
Medium (small app, web server)  → t3.medium, t3.large
Heavy (production, database)    → m6i.large or larger
```

### Step 3 — Check availability in your region
```powershell
aws ec2 describe-instance-type-offerings `
  --location-type availability-zone `
  --filters "Name=instance-type,Values=t3.micro" `
  --query "InstanceTypeOfferings[].Location" `
  --output table
```

### Instance size quick reference
| Instance | vCPU | RAM | Good for |
|----------|------|-----|----------|
| t2.micro | 1 | 1 GB | Free Tier, minimal Linux |
| t3.micro | 2 | 1 GB | Free Tier (check region), light workloads |
| t3.small | 2 | 2 GB | Minimum for Windows |
| t3.medium | 2 | 4 GB | Windows dev, small web apps |
| t3.large | 2 | 8 GB | Windows with applications |
| m6i.large | 2 | 8 GB | Production workloads |
| m6i.xlarge | 4 | 16 GB | Larger production |
| c6i.large | 2 | 4 GB | CPU-intensive |
| r6i.large | 2 | 16 GB | Memory-intensive |

---

## 7. Networking — VPC, Subnets, and Security Groups

### VPC (Virtual Private Cloud)
A VPC is your private isolated network inside AWS. Every AWS account gets one **default VPC** per region, pre-configured and ready to use. This Terraform config uses it.

```hcl
data "aws_vpc" "default" {
  default = true    # Looks up the one VPC in this region that has default=true
}
```

For production environments you would create a custom VPC with public and private subnets, NAT gateways, etc. — but for getting started, the default VPC is fine.

### Subnets
A subnet is a subdivision of the VPC, tied to one Availability Zone. The default VPC has one public subnet per AZ. This config picks the first one automatically.

```hcl
subnet_id = tolist(data.aws_subnets.default.ids)[0]
```

To place an instance in a specific AZ instead:
```hcl
data "aws_subnet" "specific" {
  filter {
    name   = "availabilityZone"
    values = ["us-east-1a"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
# then use: subnet_id = data.aws_subnet.specific.id
```

### Security Groups
A security group is a stateful firewall. Rules are evaluated together — there is no ordering.

**Inbound (ingress) rules:** What traffic can reach your instance from outside.
**Outbound (egress) rules:** What traffic your instance can send out.

```hcl
ingress {
  description = "RDP"
  from_port   = 3389      # Start of port range
  to_port     = 3389      # End of port range (same = single port)
  protocol    = "tcp"     # tcp, udp, icmp, or -1 (all)
  cidr_blocks = ["0.0.0.0/0"]   # Source IP range
}
```

**Common ports to know:**
| Port | Protocol | Use |
|------|----------|-----|
| 22 | TCP | SSH (Linux) |
| 3389 | TCP | RDP (Windows) |
| 80 | TCP | HTTP |
| 443 | TCP | HTTPS |
| 1433 | TCP | SQL Server |
| 3306 | TCP | MySQL |
| 5432 | TCP | PostgreSQL |
| 8080 | TCP | Alternate HTTP |

---

## 8. Key Pairs — SSH and RDP Password Decryption

### Creating a key pair (do this once, before running Terraform)

**In the AWS Console:**
1. Go to EC2 → Network & Security → Key Pairs
2. Click "Create key pair"
3. Name: `my-keypair` (use this name as `key_name` in `terraform.tfvars`)
4. Key pair type: RSA
5. Private key file format: `.pem` (for OpenSSH / Linux) or `.ppk` (for PuTTY on Windows)
6. Click "Create" — the `.pem` file downloads automatically
7. Move it to a safe location: `C:\Users\YourName\.ssh\my-keypair.pem`

**Via AWS CLI:**
```powershell
aws ec2 create-key-pair `
  --key-name my-keypair `
  --query "KeyMaterial" `
  --output text | Out-File -FilePath "$env:USERPROFILE\.ssh\my-keypair.pem" -Encoding ascii
```

### Windows — Decrypting the Administrator Password

After launching a Windows instance with a key pair, AWS generates a random Administrator password and encrypts it with your public key.

**Method 1 — AWS Console:**
1. EC2 Console → Instances → select instance
2. Actions → Security → Get Windows password
3. Upload your `.pem` file → Decrypt password

**Method 2 — AWS CLI:**
```powershell
aws ec2 get-password-data `
  --instance-id i-0abc12345def67890 `
  --priv-launch-key "C:\Users\YourName\.ssh\my-keypair.pem" `
  --query PasswordData `
  --output text
```

**Method 3 — From Terraform output (after apply):**
```powershell
terraform output administrator_password
```
This returns the **encrypted** password. You still need to decrypt it with your key as above.

> Note: The password takes 4–8 minutes to become available after first launch. The instance must fully boot and run Sysprep before AWS generates it.

### Linux — SSH with Key Pair

```powershell
# Fix permissions (required by SSH client)
icacls "C:\Users\YourName\.ssh\my-keypair.pem" /inheritance:r /grant:r "${env:USERNAME}:R"

# Connect (replace IP and key path)
ssh -i "C:\Users\YourName\.ssh\my-keypair.pem" ec2-user@<public_ip>
```

**Default usernames by Linux AMI:**
| AMI | Username |
|-----|----------|
| Amazon Linux | `ec2-user` |
| Ubuntu | `ubuntu` |
| RHEL | `ec2-user` |
| Debian | `admin` |
| SUSE | `ec2-user` |

---

## 9. Step-by-Step: Run Order

### First-time setup
```powershell
# 1. Install Terraform (if not installed)
winget install HashiCorp.Terraform

# 2. Verify installation
terraform version

# 3. Configure AWS credentials (one of three methods below)
```

### AWS Authentication — three methods

**Method A: Environment variables (recommended for one-off use)**
```powershell
$env:AWS_ACCESS_KEY_ID     = "AKIAIOSFODNN7EXAMPLE"
$env:AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
$env:AWS_DEFAULT_REGION    = "us-east-1"
```

**Method B: AWS CLI profile (recommended for regular use)**
```powershell
# Install AWS CLI if needed
winget install Amazon.AWSCLI

# Configure credentials — will prompt for keys
aws configure

# Credentials are stored in C:\Users\YourName\.aws\credentials
# Use a named profile for multiple accounts:
aws configure --profile myprofile
$env:AWS_PROFILE = "myprofile"
```

**Where to get your Access Key ID and Secret:**
1. AWS Console → your username (top right) → Security credentials
2. Under "Access keys" → Create access key
3. Copy both the Key ID and Secret — the secret is only shown once

**Method C: IAM Role (for EC2 or CI/CD environments — no keys needed)**
Assign an IAM role to the machine running Terraform. The AWS provider picks it up automatically.

### Deploying

```powershell
cd C:\Terraform\AWS

# Step 1: Download provider plugins (run once, or after changing providers.tf)
terraform init

# Step 2: Preview what will be created — no changes made
terraform plan

# Step 3: Create the resources
terraform apply
# Type 'yes' when prompted

# Step 4: View outputs (IP address, RDP command, etc.)
terraform output

# Step 5: When done, destroy all resources (stops AWS billing)
terraform destroy
# Type 'yes' when prompted
```

### Modifying an existing deployment
```powershell
# Edit terraform.tfvars, then:
terraform plan    # See what will change
terraform apply   # Apply the changes
```

Terraform is smart — it only changes what is different. Changing `instance_name` just updates the tag. Changing `instance_type` stops and restarts the instance. Changing the AMI replaces the instance entirely.

---

## 10. Recipes — Ready-to-Use OS Examples

To use a recipe: copy the `data "aws_ami"` block into `main.tf`, update the `aws_instance` reference, and adjust `terraform.tfvars` as noted.

### Recipe A: Windows Server 2019

```hcl
# In main.tf — replace the data "aws_ami" block
data "aws_ami" "windows_2019" {
  most_recent = true
  owners      = ["amazon"]

  filter { name = "name",             values = ["Windows_Server-2019-English-Full-Base-*"] }
  filter { name = "architecture",     values = ["x86_64"] }
  filter { name = "virtualization-type", values = ["hvm"] }
  filter { name = "state",            values = ["available"] }
}

# In the aws_instance resource, change the ami line to:
ami = data.aws_ami.windows_2019.id
```

```hcl
# terraform.tfvars
instance_type    = "t3.micro"
root_volume_size = 50
```

---

### Recipe B: Amazon Linux 2023 (Free Tier)

```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter { name = "name",             values = ["al2023-ami-*-x86_64"] }
  filter { name = "architecture",     values = ["x86_64"] }
  filter { name = "virtualization-type", values = ["hvm"] }
  filter { name = "state",            values = ["available"] }
}

# aws_instance resource:
ami = data.aws_ami.amazon_linux_2023.id
```

```hcl
# terraform.tfvars — also switch to allowed_ssh_cidr in variables.tf
instance_type    = "t2.micro"
root_volume_size = 20
```

Also update the security group in `main.tf`: replace the RDP port `3389` ingress with SSH port `22`, and rename `allowed_rdp_cidr` to `allowed_ssh_cidr` in both `variables.tf` and `terraform.tfvars`.

---

### Recipe C: Ubuntu 22.04 LTS

```hcl
data "aws_ami" "ubuntu_22" {
  most_recent = true
  owners      = ["099720109477"]   # Canonical

  filter { name = "name",             values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] }
  filter { name = "architecture",     values = ["x86_64"] }
  filter { name = "virtualization-type", values = ["hvm"] }
  filter { name = "state",            values = ["available"] }
}
```

```hcl
# terraform.tfvars
instance_type    = "t2.micro"
root_volume_size = 20
```

SSH username: `ubuntu`

---

### Recipe D: Red Hat Enterprise Linux 9

```hcl
data "aws_ami" "rhel9" {
  most_recent = true
  owners      = ["309956199498"]   # Red Hat

  filter { name = "name",             values = ["RHEL-9.*_HVM-*-x86_64-*"] }
  filter { name = "architecture",     values = ["x86_64"] }
  filter { name = "virtualization-type", values = ["hvm"] }
  filter { name = "state",            values = ["available"] }
}
```

```hcl
# terraform.tfvars
instance_type    = "t3.medium"
root_volume_size = 30
```

SSH username: `ec2-user`

---

### Recipe E: Windows Server 2022 with SQL Server 2022 Standard

```hcl
data "aws_ami" "windows_sql" {
  most_recent = true
  owners      = ["amazon"]

  filter { name = "name",  values = ["Windows_Server-2022-English-Full-SQL_2022_Standard-*"] }
  filter { name = "state", values = ["available"] }
}
```

```hcl
# terraform.tfvars — SQL Server needs more resources
instance_type    = "m6i.large"   # SQL Server minimum recommended
root_volume_size = 100
```

> This AMI includes a pre-installed licensed SQL Server — AWS charges the SQL Server license fee per hour on top of the instance cost.

---

## 11. Common Errors and Fixes

### `InvalidParameterCombination: not eligible for Free Tier`
**Cause:** The instance type you specified is not Free Tier eligible.
**Fix:** Change `instance_type` to `t2.micro` in `terraform.tfvars`. Verify with:
```powershell
aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true --query "InstanceTypes[].InstanceType" --output table
```

---

### `AuthFailure: AWS was not able to validate the provided access credentials`
**Cause:** Your AWS credentials are wrong, expired, or not set.
**Fix:**
```powershell
aws sts get-caller-identity   # If this works, credentials are valid
aws configure                 # Re-enter credentials
```

---

### `OptInRequired: In order to use this AWS Marketplace product you need to accept terms`
**Cause:** Some AMIs (RHEL, SUSE, certain Windows editions) require marketplace subscription acceptance.
**Fix:** Open the AMI in the AWS Marketplace console and click "Accept Terms". Then re-run Terraform.

---

### `InvalidAMIID.NotFound`
**Cause:** The AMI filter returned no results, usually because the name pattern or owner is wrong for this region.
**Fix:** Run the CLI query from Section 5 to find the exact AMI name in your region. AMI names differ slightly between regions.

---

### `VPCIdNotSpecified: No default VPC for this user`
**Cause:** The default VPC was deleted from the account.
**Fix:**
```powershell
aws ec2 create-default-vpc
```
Or specify a VPC ID explicitly in the `data "aws_vpc"` block using `id = "vpc-xxxxxxxx"` instead of `default = true`.

---

### `Error: Password not yet available`
**Cause:** Windows instance just launched and hasn't finished booting.
**Fix:** Wait 5–10 minutes and run `terraform refresh` or query via CLI again.

---

### `terraform plan` shows "changes" even though nothing changed
**Cause:** AWS may return subnets in a different order each time — `tolist(...)[0]` can pick a different subnet.
**Fix:** Pin the subnet by AZ using a specific data source (see Section 7).

---

## 12. AWS CLI Cheat Sheet

```powershell
# List your EC2 instances
aws ec2 describe-instances `
  --query "Reservations[].Instances[].{ID:InstanceId, Type:InstanceType, State:State.Name, IP:PublicIpAddress, Name:Tags[?Key=='Name'].Value|[0]}" `
  --output table

# List available regions
aws ec2 describe-regions --query "Regions[].RegionName" --output table

# Find Free Tier instance types
aws ec2 describe-instance-types `
  --filters Name=free-tier-eligible,Values=true `
  --query "InstanceTypes[].InstanceType" --output table

# Find latest Windows Server 2022 AMI
aws ec2 describe-images `
  --owners amazon `
  --filters "Name=name,Values=Windows_Server-2022-English-Full-Base-*" "Name=state,Values=available" `
  --query "sort_by(Images, &CreationDate)[-1].{ID:ImageId, Name:Name}" --output table

# Find latest Ubuntu 22.04 AMI
aws ec2 describe-images `
  --owners 099720109477 `
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" "Name=state,Values=available" `
  --query "sort_by(Images, &CreationDate)[-1].{ID:ImageId, Name:Name}" --output table

# Get Windows Administrator password
aws ec2 get-password-data `
  --instance-id i-0abc12345 `
  --priv-launch-key "C:\Users\YourName\.ssh\keypair.pem" `
  --query PasswordData --output text

# Stop an instance (keeps it, stops billing for compute — disk is still charged)
aws ec2 stop-instances --instance-ids i-0abc12345

# Start it again
aws ec2 start-instances --instance-ids i-0abc12345

# List your key pairs
aws ec2 describe-key-pairs --query "KeyPairs[].KeyName" --output table

# List security groups
aws ec2 describe-security-groups `
  --query "SecurityGroups[].{ID:GroupId, Name:GroupName, VPC:VpcId}" --output table

# Check your identity (confirm credentials are working)
aws sts get-caller-identity
```

---

*End of documentation. For the latest AWS provider resource arguments, see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance*
