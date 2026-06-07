# ☁️ Oracle Cloud Always Free — Instance Retry Script

![Shell Script](https://img.shields.io/badge/Shell-Bash-green?logo=gnubash&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white)
![Oracle Cloud](https://img.shields.io/badge/Cloud-Oracle%20OCI-F80000?logo=oracle&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)

> **Automatically retry provisioning an Oracle Cloud Always Free ARM (A1.Flex) compute instance until capacity becomes available.**

Oracle's Always Free Tier offers up to **4 OCPU / 24 GB RAM** on Ampere A1 ARM instances — but availability is extremely limited. This project automates the retry process using Terraform, so you don't have to sit at the console clicking "Create" hundreds of times.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔄 **Auto-Retry Loop** | Runs `terraform apply` every 45 seconds until the instance is successfully created |
| 📢 **Discord Notifications** | Sends real-time alerts to a Discord channel on start, success, and rate-limit events |
| 📝 **Log Rotation** | Automatically rotates logs when they exceed 10 MB to prevent disk bloat |
| 🔒 **Lock File Protection** | Prevents duplicate script instances from running simultaneously |
| 🛡️ **Rate-Limit Handling** | Detects OCI 429/TooManyRequests errors and backs off for 10 minutes |
| 🔁 **Reboot-Safe** | Can be made persistent across reboots with a simple crontab entry |

---

## 📁 Project Structure

```
oracle-retry/
├── main.tf                      # Terraform config for OCI instance + networking
├── retry_oracle_instance.sh     # Main retry loop script
├── cleanup_retry.sh             # Gracefully stop the retry process
├── .gitignore                   # Excludes secrets, state, and logs
└── README.md                    # You are here
```

**Not tracked (you must provide):**
```
├── oci_api_key.pem              # Your OCI API private key
├── .terraform/                  # Terraform provider cache (auto-generated)
├── terraform.tfstate            # Terraform state (auto-generated)
├── retry.log                    # Runtime logs (auto-generated)
├── retry.pid                    # PID tracking file (auto-generated)
└── .env                         # Environment variables for webhook (you must create)
```

---

## 🚀 Quick Start

### Prerequisites

- A Linux server (Ubuntu recommended) with internet access
- [Terraform](https://developer.hashicorp.com/terraform/install) installed
- An [Oracle Cloud](https://cloud.oracle.com/) Always Free account
- OCI API key pair generated ([how-to guide](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm))
- *(Optional)* A [Discord webhook URL](https://support.discord.com/hc/en-us/articles/228383668) for notifications

### Step 1: Clone the Repository

```bash
git clone https://github.com/shanuv000/oracle-retry.git
cd oracle-retry
```

### Step 2: Add Your API Key

Place your OCI API private key in the project directory:

```bash
cp /path/to/your/oci_api_key.pem ./oci_api_key.pem
chmod 600 oci_api_key.pem
```

### Step 3: Configure `main.tf`

Edit `main.tf` and replace the placeholder values with your own:

```hcl
provider "oci" {
  tenancy_ocid     = "ocid1.tenancy.oc1..your-tenancy-ocid"
  user_ocid        = "ocid1.user.oc1..your-user-ocid"
  fingerprint      = "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99"
  private_key_path = "${path.module}/oci_api_key.pem"
  region           = "ap-tokyo-1"  # Change to your desired region
}
```

Also update:
- `compartment_id` — your tenancy/compartment OCID
- `ssh_authorized_keys` — your public SSH key
- `display_name` — name for your instance
- `shape_config` — OCPU and memory (start small: 1 OCPU / 6 GB)

### Step 4: Configure Discord Webhook *(Optional)*

Create a `.env` file in the project directory and set your webhook URL:

```bash
echo "DISCORD_WEBHOOK=\"https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN\"" > .env
```

If you do not wish to use Discord notifications, you can leave the webhook URL blank in the `.env` file.

### Step 5: Initialize Terraform

```bash
terraform init
```

### Step 6: Start the Retry Script

```bash
nohup ./retry_oracle_instance.sh >> /dev/null 2>&1 &
```

The script will now run in the background, retrying every 45 seconds.

---

## 🔁 Making it Reboot-Safe

Add a crontab entry so the script automatically restarts after a server reboot:

```bash
crontab -e
```

Add this line:

```
@reboot cd /path/to/oracle-retry && nohup ./retry_oracle_instance.sh >> /dev/null 2>&1 &
```

Alternatively, you can set it up as a `systemd` service for more robust persistence.

---

## 📊 Monitoring

### Check if the script is running

```bash
ps aux | grep retry_oracle_instance
```

### View live logs

```bash
tail -f retry.log
```

### Check attempt count

```bash
grep -c 'FAILED\|SUCCESS' retry.log
```

---

## 🛑 Stopping the Script

**Option 1:** Use the cleanup script:

```bash
./cleanup_retry.sh
```

> ⚠️ This will also **delete** the retry script itself. Use Option 2 if you want to keep the files.

**Option 2:** Manual stop:

```bash
kill $(cat retry.pid)
```

---

## 💡 Pro Tips

### Start Small, Scale Later

Oracle's capacity is extremely limited for large ARM shapes. The winning strategy is:

1. **Request a small instance first** (1 OCPU / 6 GB RAM)
2. **Once created**, stop the instance in the OCI console
3. **Resize** to 4 OCPU / 24 GB RAM / 200 GB boot volume
4. **Start** the instance again — scaling is guaranteed once you have a slot

### Try Multiple Regions

Capacity varies widely by region. Consider running parallel retry scripts targeting different regions:

| Region | Code | Typical Wait |
|---|---|---|
| Mumbai | `ap-mumbai-1` | Days to weeks |
| Tokyo | `ap-tokyo-1` | Days to weeks |
| Phoenix | `us-phoenix-1` | Moderate |
| Ashburn | `us-ashburn-1` | Moderate |
| Seoul | `ap-seoul-1` | Variable |

### Try Multiple Availability Domains

Some regions have multiple ADs. Edit `main.tf` to target a different one:

```hcl
# AD index: 0, 1, or 2 (depends on region)
availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
```

---

## 🏗️ How It Works

```
┌─────────────────────────────────┐
│     retry_oracle_instance.sh    │
│                                 │
│  ┌───────────┐                  │
│  │  Start    │                  │
│  └─────┬─────┘                  │
│        ▼                        │
│  ┌─────────────┐                │
│  │ Lock Check  │──── Already ──→ Exit
│  └─────┬───────┘    running     │
│        ▼                        │
│  ┌─────────────────┐            │
│  │ terraform apply  │            │
│  └────┬────────┬───┘            │
│       │        │                │
│    Success   Failed             │
│       │        │                │
│       ▼        ├── Rate limit → Sleep 10 min
│   Discord      │                │
│   Notify       └── Capacity  → Sleep 45 sec
│   + Exit              error     │
│                        │        │
│                        ▼        │
│                   Retry Loop ◄──┘
└─────────────────────────────────┘
```

---

## 📄 License

MIT — Use it, fork it, share it. Good luck getting your free instance! 🍀

---

## 🙏 Acknowledgments

- [Oracle Cloud Always Free Tier](https://www.oracle.com/cloud/free/)
- [Terraform OCI Provider](https://registry.terraform.io/providers/oracle/oci/latest)
- Inspired by the community of developers trying to grab those elusive ARM instances