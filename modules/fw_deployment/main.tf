variable "fwimage_pri" {}
variable "fwimageid_pri" {}
variable "fwimage_bak" {}
variable "fwimageid_bak" {}
variable "instancetype" {}
variable "alicloud_security_group-MGMT-SG" {}
variable "name" {}
variable "name-2" {}
variable "mgmt-vswitchid" {}
variable "mgmt-vswitch-2id" {}
variable "alicloud_eip-MGMT-EIPid" {}
variable "alicloud_eip-MGMT-EIP-2id" {}
variable "mgmtip" {}
variable "mgmt-2ip" {}
variable "data-trust-vswitchid" {}
variable "data-trust-vswitch-2id" {}
variable "TRUST-SGid" {}
variable "trustip" {}
variable "trust-2ip" {}
variable "data-untrust-vswitchid" {}
variable "data-untrust-vswitch-2id" {}
variable "UNTRUST-SGid" {}
variable "untrustip" {}
variable "untrust-2ip" {}
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "route_table_id" {}
variable "default_egress_route" {}
variable "random" {}



provider alicloud {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
  alias      = "provider"
}

data "alicloud_images" "vmseries" {
  provider              = "alicloud.provider"
  owners       = "marketplace"
  name_regex   = "VM-Series 9.1.3"
}

resource "alicloud_instance" "ngfw" {
  provider              = "alicloud.provider"
  image_id              = data.alicloud_images.vmseries.images[0].id
  instance_type         = "${var.instancetype}"
  system_disk_size      = 80
  system_disk_category  = "cloud_efficiency"
  security_groups       = ["${var.alicloud_security_group-MGMT-SG}"]
  instance_name         = "${var.name}-${var.random}"
  vswitch_id            = "${var.mgmt-vswitchid}"
  private_ip            = "${var.mgmtip}"
  # host_name             = "${var.hkname}"
  description           = "VM-series instance DEMO"
  security_enhancement_strategy = "Active"
 # internet_max_bandwidth_out = 0    # No Public IP assigned since we are attaching EIP
  instance_charge_type  = "PostPaid"
}

resource "alicloud_instance" "ngfw-2" {
  provider              = "alicloud.provider"
  image_id              = data.alicloud_images.vmseries.images[0].id
  instance_type         = "${var.instancetype}"
  system_disk_size      = 80
  system_disk_category  = "cloud_efficiency"
  security_groups       = ["${var.alicloud_security_group-MGMT-SG}"]
  instance_name         = "${var.name-2}-${var.random}"
  vswitch_id            = "${var.mgmt-vswitch-2id}"
  private_ip            = "${var.mgmt-2ip}"
  # host_name             = "${var.hkname}"
  description           = "VM-series instance DEMO-2"
  security_enhancement_strategy = "Active"
 # internet_max_bandwidth_out = 0    # No Public IP assigned since we are attaching EIP
  instance_charge_type  = "PostPaid"
}

# Attach EIP#  to  Mgmt
resource "alicloud_eip_association" "Mgmt-EIP-Association" {
  provider      = "alicloud.provider"
  allocation_id = "${var.alicloud_eip-MGMT-EIPid}"
  instance_id   = "${alicloud_instance.ngfw.id}"
  #depends_on = ["alicloud_eip.hk-MGMT-EIP" , "alicloud_vswitch.hk-mgmt-vswitch" ]
}

resource "alicloud_eip_association" "Mgmt-EIP-Association-2" {
  provider      = "alicloud.provider"
  allocation_id = "${var.alicloud_eip-MGMT-EIP-2id}"
  instance_id   = "${alicloud_instance.ngfw-2.id}"
  #depends_on = ["alicloud_eip.hk-MGMT-EIP" , "alicloud_vswitch.hk-mgmt-vswitch" ]
}
# Attach ENI to Trust

resource "alicloud_network_interface" "trust-interface" {
  provider      = "alicloud.provider"
  name = "VM-series-trust-interface"
  vswitch_id = "${var.data-trust-vswitchid}"
  security_groups = [ "${var.TRUST-SGid}"]
  private_ip = "${var.trustip}" 
  #depends_on = ["alicloud_vpc.hk_vpc" ]
}

resource "alicloud_network_interface" "trust-interface-2" {
  provider      = "alicloud.provider"
  name = "VM-series-trust-interface-2"
  vswitch_id = "${var.data-trust-vswitch-2id}"
  security_groups = [ "${var.TRUST-SGid}"]
  private_ip = "${var.trust-2ip}" 
  #depends_on = ["alicloud_vpc.hk_vpc" ]
}
resource "alicloud_network_interface_attachment" "attach-trust" {
  provider      = "alicloud.provider"
  instance_id = "${alicloud_instance.ngfw.id}"
  network_interface_id = "${alicloud_network_interface.trust-interface.id}"
  #depends_on = ["alicloud_network_interface_attachment.attach-untrust","alicloud_vpc.hk_vpc" ]

}

resource "alicloud_network_interface_attachment" "attach-trust-2" {
  provider      = "alicloud.provider"
  instance_id = "${alicloud_instance.ngfw-2.id}"
  network_interface_id = "${alicloud_network_interface.trust-interface-2.id}"
  #depends_on = ["alicloud_network_interface_attachment.attach-untrust","alicloud_vpc.hk_vpc" ]

}
resource "alicloud_network_interface" "untrust-interface" {
  provider      = "alicloud.provider"
  name = "VM-series-untrust-interface"
  vswitch_id = "${var.data-untrust-vswitchid}"
  security_groups = [ "${var.UNTRUST-SGid}" ]
  private_ip = "${var.untrustip}" 
  depends_on = ["alicloud_network_interface_attachment.attach-trust", "alicloud_network_interface_attachment.attach-trust-2"]
}

resource "alicloud_network_interface" "untrust-interface-2" {
  provider      = "alicloud.provider"
  name = "VM-series-untrust-interface-2"
  vswitch_id = "${var.data-untrust-vswitch-2id}"
  security_groups = [ "${var.UNTRUST-SGid}" ]
  private_ip = "${var.untrust-2ip}" 
  depends_on = ["alicloud_network_interface_attachment.attach-trust", "alicloud_network_interface_attachment.attach-trust-2"]
}
resource "alicloud_network_interface_attachment" "attach-untrust" {
  provider      = "alicloud.provider"
  instance_id = "${alicloud_instance.ngfw.id}"
  network_interface_id = "${alicloud_network_interface.untrust-interface.id}"
  depends_on = ["alicloud_network_interface_attachment.attach-trust", "alicloud_network_interface_attachment.attach-trust-2"]
}

resource "alicloud_network_interface_attachment" "attach-untrust-2" {
  provider      = "alicloud.provider"
  instance_id = "${alicloud_instance.ngfw-2.id}"
  network_interface_id = "${alicloud_network_interface.untrust-interface-2.id}"
  depends_on = ["alicloud_network_interface_attachment.attach-trust", "alicloud_network_interface_attachment.attach-trust-2"]
}


resource "alicloud_route_entry" "egress" {
  // The Default Route
  provider = "alicloud.provider"
  route_table_id = "${var.route_table_id}"
  destination_cidrblock = "${var.default_egress_route}" //Default is 0.0.0.0/0
  nexthop_type = "NetworkInterface"
  nexthop_id = "${alicloud_network_interface.trust-interface.id}"
}

data "alicloud_eips" "untrust_eip" {
  provider              = "alicloud.provider"
  ids   = ["${var.alicloud_eip-MGMT-EIPid}"]
  #depends_on = ["alicloud_vpc.hk_vpc" ]
}

data "alicloud_eips" "untrust_eip-2" {
  provider              = "alicloud.provider"
  ids   = ["${var.alicloud_eip-MGMT-EIP-2id}"]
  #depends_on = ["alicloud_vpc.hk_vpc" ]
}

data "alicloud_eips" "all_eips" {
provider = "alicloud.provider"
depends_on = ["alicloud_eip_association.Mgmt-EIP-Association", "alicloud_eip_association.Mgmt-EIP-Association-2"]
}

resource "null_resource" "dependency_setter" {

  depends_on = [
    "alicloud_network_interface_attachment.attach-untrust",
    "alicloud_network_interface_attachment.attach-untrust-2",
    "alicloud_network_interface.untrust-interface",
    "alicloud_network_interface.untrust-interface-2",
    "alicloud_network_interface_attachment.attach-trust",
    "alicloud_network_interface_attachment.attach-trust-2",
    "alicloud_network_interface.trust-interface",
    "alicloud_network_interface.trust-interface-2",
    "alicloud_eip_association.Mgmt-EIP-Association",
    "alicloud_eip_association.Mgmt-EIP-Association-2",
    "alicloud_instance.ngfw",
    "alicloud_instance.ngfw-2"
  ]
}
output "trust-interface-pri" {
  value = "${alicloud_network_interface.trust-interface.id}"
}

output "trust-interface-bak" {
  value = "${alicloud_network_interface.trust-interface-2.id}"
}
output "untrust-interface-pri" {
  value = "${alicloud_network_interface.untrust-interface.id}"
}
output "untrust-interface-bak" {
  value = "${alicloud_network_interface.untrust-interface-2.id}"
}
output completion {
  value = "${null_resource.dependency_setter.id}"
}
