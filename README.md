# Oracle Cloud Instance Retry Script

This project automatically retries provisioning an Oracle Cloud Always Free A1 compute instance when capacity is full.

## Setup
1. Add your `oci_api_key.pem`
2. Update `main.tf` with your compartment and tenancy OCIDs.
3. Run `./retry_oracle_instance.sh` to start.

## Features
- 2-minute retry loop
- Discord webhook notifications
- Log rotation
- Reboot-safe via crontab