# This file was autogenerate by the BETA 'packer hcl2_upgrade' command. We
# recommend double checking that everything is correct before going forward. We
# also recommend treating this file as disposable. The HCL2 blocks in this
# file can be moved to other files. For example, the variable blocks could be
# moved to their own 'variables.pkr.hcl' file, etc. Those files need to be
# suffixed with '.pkr.hcl' to be visible to Packer. To use multiple files at
# once they also need to be in the same folder. 'packer inspect folder/'
# will describe to you what is in that folder.

# All generated input variables will be of string type as this how Packer JSON
# views them; you can later on change their type. Read the variables type
# constraints documentation
# https://www.packer.io/docs/from-1.5/variables#type-constraints for more info.
# "timestamp" template function replacement
locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

# source blocks are generated from your builders; a source can be referenced in
# build blocks. A build block runs provisioner and post-processors onto a
# source. Read the documentation for source blocks here:
# https://www.packer.io/docs/from-1.5/blocks/source
source "qemu" "autogenerated_1" {
  accelerator      = "kvm"
  boot_wait        = "5m"
  communicator     = "winrm"
  disk_compression = "${var.compress}"
  disk_size        = "${var.disk_size}"
  floppy_files     = "${var.floppy_files_list}"
  format           = "${var.disk_format}"
  headless         = true
  iso_checksum     = "${var.iso_checksum_type}:${var.iso_checksum}"
  iso_urls         = ["${var.iso_url}"]
  output_directory = "output-${var.name}-${local.timestamp}"
  qemuargs         = [["-m", "4096M"], ["-cpu", "Westmere"], ["-m", "${var.memory}"], ["-smp", "cpus=${var.cpus}"]]
  shutdown_command = "C:\\Windows\\packer\\shutdown.bat"
  shutdown_timeout = "1h"
  vm_name          = "${var.name}-${local.timestamp}"
  winrm_insecure   = "true"
  winrm_password   = "${var.packer_pass}"
  winrm_port       = "5986"
  winrm_timeout    = "4h"
  winrm_use_ssl    = "true"
  winrm_username   = "${var.packer_user}"
}

source "vsphere-iso" "autogenerated_2" {
  CPUs                 = "${var.cpus}"
  RAM                  = "${var.memory}"
  RAM_reserve_all      = true
  cluster              = "${var.vsphere-cluster}"
  communicator         = "winrm"
  convert_to_template  = "true"
  datacenter           = "${var.vsphere-datacenter}"
  datastore            = "${var.vsphere-datastore}"
  disk_controller_type = "pvscsi"
  firmware             = "bios"
  floppy_files         = "${var.floppy_files_list}"
  folder               = "${var.vsphere-folder}"
  guest_os_type        = "windows9Server64Guest"
  insecure_connection  = "true"
  iso_checksum         = "${var.iso_checksum_type}:${var.iso_checksum}"
  iso_paths            = ["[] /vmimages/tools-isoimages/windows.iso"]
  iso_urls             = ["${var.iso_url}"]
  network_adapters {
    network      = "${var.vsphere-network}"
    network_card = "vmxnet3"
  }
  password         = "${var.vsphere-password}"
  shutdown_command = "C:\\Windows\\packer\\shutdown.bat"
  shutdown_timeout = "1h"
  storage {
    disk_size             = "${var.disk_size}"
    disk_thin_provisioned = true
  }
  username       = "${var.vsphere-user}"
  vcenter_server = "${var.vsphere-server}"
  vm_name        = "${var.name}-${local.timestamp}"
  winrm_insecure = "true"
  winrm_password = "${var.packer_pass}"
  winrm_timeout  = "4h"
  winrm_use_ssl  = "true"
  winrm_username = "${var.packer_user}"
}

# a build block invokes sources and runs provisionning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/from-1.5/blocks/build
build {
  sources = ["source.qemu.autogenerated_1", "source.vsphere-iso.autogenerated_2"]

  provisioner "windows-shell" {
    scripts = ["scripts/unlimited-password-expiration.bat", "scripts/uac-disable.bat", "scripts/disable-hibernate.bat"]
  }
  provisioner "powershell" {
    scripts = ["scripts/set_firewall_rules.ps1", "scripts/install-choco.ps1", "scripts/Set-PowerSettings.ps1", "scripts/Set-WindowsTelemetrySettings.ps1", "scripts/dis-updates.ps1"]
  }
  provisioner "powershell" {
    inline = ["Write-Host \"Installing Tools\"", "choco install googlechrome 7zip notepadplusplus choco-cleaner git.install bginfo procexp", "New-Item -Path 'C:\\Windows\\Setup\\Scripts' -ItemType Directory -Force", "New-Item -Path \"C:\\Windows\\packer\" -ItemType Directory -Force"]
  }
  provisioner "file" {
    destination = "C:\\Windows\\packer\\"
    sources     = ["autounattend/sysprep/unattended.xml", "scripts/shutdown.bat"]
  }
  provisioner "file" {
    destination = "C:\\ProgramData\\chocolatey\\lib\\bginfo\\Tools\\"
    source      = "scripts/bginfo.bgi"
  }
  provisioner "file" {
    destination = "C:\\Windows\\Setup\\Scripts\\SetupComplete.cmd"
    source      = "scripts/SetupComplete.cmd"
  }
  provisioner "powershell" {
    script = "scripts/cleanup.ps1"
  }
  post-processors {
    post-processor "compress" {
      format = ".tar.gz"
      name   = "pack"
      only   = ["qemu"]
      output = "${var.name}.tar.gz"
    }
    post-processor "shell-local" {
      inline = ["gsutil cp output/disk.raw.tar.gz gs://${var.gcs_bucket}/${var.image_family}-${local.timestamp}.tar.gz", "gcloud compute images create ${var.image_family}-${local.timestamp} \\", "--source-uri=gs://${var.gcs_bucket}/${var.image_family}-${local.timestamp}.tar.gz \\", "--family=${var.image_family}"]
      name   = "gcp"
      only   = ["qemu"]
    }
    post-processor "shell-local" {
      inline = ["/usr/bin/ovftool output_${var.name}/${var.name}.ovf output_${var.name}/${var.name}.ova", "rm -vf output_${var.name}/${var.name}.ovf output_${var.name}/${var.name}.mf output_${var.name}/${var.name}-disk-0.vmdk"]
      name   = "convert-to-ova"
      only   = ["vsphere-iso"]
    }
    post-processor "artifice" {
      files = ["output_${var.name}/${var.name}.ova"]
      only  = ["vsphere-iso"]
    }
    post-processor "amazon-import" {
      keep_input_artifact = false
      access_key          = "${var.aws_access_key}"
      license_type        = "BYOL"
      name                = "aws"
      only                = ["vsphere-iso"]
      region              = "${var.aws_region}"
      s3_bucket_name      = "${var.aws_s3_bucket_name}"
      s3_key_name         = "${var.name}.ova"
      secret_key          = "${var.aws_secret_key}"
      tags = {
        Description = "packer amazon-import ${local.timestamp}"
      }
    }
  }
}
