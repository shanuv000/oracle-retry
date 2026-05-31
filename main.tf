terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

provider "oci" {
  tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaaordtacnhr33fnjrwixcqo2sv5zdlfyybmfpnh7z35unblwqm53yq"
  user_ocid        = "ocid1.user.oc1..aaaaaaaatylc64yx3k5ncfhmiwkbmekwwhiqdld2qtjjhq7ttat5gv5tr66a"
  fingerprint      = "d0:f6:f3:c9:30:e4:93:d6:f2:33:1e:ae:bc:f3:11:b5"
  private_key_path = "${path.module}/oci_api_key.pem"
  region           = "ap-tokyo-1"
}

# --- Availability Domain Lookup ---
data "oci_identity_availability_domains" "ads" {
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaaordtacnhr33fnjrwixcqo2sv5zdlfyybmfpnh7z35unblwqm53yq"
}

# --- Latest Oracle Linux aarch64 Image ---
data "oci_core_images" "oracle_linux_arm" {
  compartment_id           = "ocid1.tenancy.oc1..aaaaaaaaordtacnhr33fnjrwixcqo2sv5zdlfyybmfpnh7z35unblwqm53yq"
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# --- Compute Instance ---
resource "oci_core_instance" "proshanu_instance" {
  agent_config {
    is_management_disabled = "false"
    is_monitoring_disabled = "false"

    plugins_config {
      desired_state = "DISABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute Instance Run Command"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute RDMA GPU Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Oracle Autonomous Linux"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "OS Management Service Agent"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "OS Management Hub Agent"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Auto-Configuration"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Authentication"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Cloud Guard Workload Protection"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Block Volume Management"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Bastion"
    }
  }

  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }

  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name

  compartment_id = "ocid1.tenancy.oc1..aaaaaaaaordtacnhr33fnjrwixcqo2sv5zdlfyybmfpnh7z35unblwqm53yq"

  create_vnic_details {
    assign_ipv6ip              = "false"
    assign_private_dns_record  = "true"
    assign_public_ip           = "true"
    display_name               = "proshanu-vnic"
    subnet_id                  = oci_core_subnet.proshanu_subnet.id
  }

  display_name = "proshanu-instance"

  instance_options {
    are_legacy_imds_endpoints_disabled = "false"
  }

  is_pv_encryption_in_transit_enabled = "true"

  metadata = {
    "ssh_authorized_keys" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKDo7M17mEPWirwhM63RwOCu9/lWDcVa0mhuqi9Pjf1u smattyvaibhav@gmail.com"
  }

  shape = "VM.Standard.A1.Flex"

  shape_config {
    memory_in_gbs = "6"
    ocpus         = "1"
  }

  source_details {
    boot_volume_size_in_gbs = "50"
    boot_volume_vpus_per_gb = "10"
    source_id               = data.oci_core_images.oracle_linux_arm.images[0].id
    source_type             = "image"
  }
}

# --- VCN ---
resource "oci_core_vcn" "proshanu_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaaordtacnhr33fnjrwixcqo2sv5zdlfyybmfpnh7z35unblwqm53yq"
  display_name   = "proshanu-vcn"
  dns_label      = "proshanuvnc"
}

# --- Subnet ---
resource "oci_core_subnet" "proshanu_subnet" {
  cidr_block     = "10.0.0.0/24"
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaaordtacnhr33fnjrwixcqo2sv5zdlfyybmfpnh7z35unblwqm53yq"
  display_name   = "proshanu-subnet"
  dns_label      = "proshanusub"
  route_table_id = oci_core_vcn.proshanu_vcn.default_route_table_id
  vcn_id         = oci_core_vcn.proshanu_vcn.id
}

# --- Internet Gateway ---
resource "oci_core_internet_gateway" "proshanu_igw" {
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaaordtacnhr33fnjrwixcqo2sv5zdlfyybmfpnh7z35unblwqm53yq"
  display_name   = "proshanu-internet-gateway"
  enabled        = "true"
  vcn_id         = oci_core_vcn.proshanu_vcn.id
}

# --- Default Route Table ---
resource "oci_core_default_route_table" "proshanu_route_table" {
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.proshanu_igw.id
  }
  manage_default_resource_id = oci_core_vcn.proshanu_vcn.default_route_table_id
}