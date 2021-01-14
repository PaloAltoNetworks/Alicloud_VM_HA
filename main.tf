## This is Developed by Mason Yan and Daniel Ma from Palo Alto Networks. 
## This is a Demo package to install two VM series NGFW and two nginx servers for HA function on AliCloud. 
## Now you can use this but has not been fully tested and supported. 
## Please use or modify it at your own discretion and after sufficient testing..



# Configure the Alicloud Provider for the region
provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
  profile = var.profile
  alias      = "provider"
}

variable "profile" {
  default = "default"
}

//Random 3 char string appended to the ened of each name to avoid conflicts
resource "random_string" "random_name_post" {
  length           = 3
  special          = true
  override_special = ""
  min_lower        = 3
}

# Get  region zones
data "alicloud_zones" "zone" {
  provider = alicloud.provider
  available_instance_type = "${var.vm-series_instance_type}"
  available_disk_category = "cloud_efficiency"
}

####################################################
# Create VPC, VSwitch, EIP and Security Group 
####################################################


resource "alicloud_vpc" "demo_vpc" {
  provider = "alicloud.provider"
  name        = "VPC_HA-${random_string.random_name_post.result}"
  cidr_block  = "${var.demo-vpc-cidr}"
  description = "VPC for VMFW in ${var.region}"
}

# Create VSwitch 
####################################################
resource "alicloud_vswitch" "mgmt-vswitch" {
  provider = "alicloud.provider"
  name              = "Mgmt-VSwitch-${random_string.random_name_post.result}"
  vpc_id            = "${alicloud_vpc.demo_vpc.id}"
  cidr_block        = "${var.mgmt-vswitch-cidr}"
  availability_zone = "${data.alicloud_zones.zone.zones.0.id}"
  description       = "VSwitch for VM-series Mgmt"
  depends_on = ["alicloud_vpc.demo_vpc" ]
}

resource "alicloud_vswitch" "mgmt-vswitch-2" {
  provider = "alicloud.provider"
  name              = "Mgmt-VSwitch-2-${random_string.random_name_post.result}"
  vpc_id            = "${alicloud_vpc.demo_vpc.id}"
  cidr_block        = "${var.mgmt-vswitch-cidr-2}"
  availability_zone = "${data.alicloud_zones.zone.zones.1.id}"
  description       = "VSwitch for VM-series  Mgmt-2"
  depends_on = ["alicloud_vpc.demo_vpc" ]
}

# Create VSwitch Trust
####################################################
resource "alicloud_vswitch" "data-trust-vswitch" {
  provider = "alicloud.provider"
  name              = "Private-VSwitch-${random_string.random_name_post.result}"
  vpc_id            = "${alicloud_vpc.demo_vpc.id}"
  cidr_block        = "${var.demo-trust-vswitch-cidr}"
  availability_zone = "${data.alicloud_zones.zone.zones.0.id}"
  description       = "VSwitch for VM-series Trust interface"
  depends_on = ["alicloud_vpc.demo_vpc" ]
}

resource "alicloud_vswitch" "data-trust-vswitch-2" {
  provider = "alicloud.provider"
  name              = "Private-VSwitch-2-${random_string.random_name_post.result}"
  vpc_id            = "${alicloud_vpc.demo_vpc.id}"
  cidr_block        = "${var.demo-trust-vswitch-cidr-2}"
  availability_zone = "${data.alicloud_zones.zone.zones.1.id}"
  description       = "VSwitch for VM-series Trust interface-2"
  depends_on = ["alicloud_vpc.demo_vpc" ]
}

# Create VSwitch For Untrust
####################################################
resource "alicloud_vswitch" "data-untrust-vswitch" {
  provider = "alicloud.provider"
  name              = "Public-VSwitch-${random_string.random_name_post.result}"
  vpc_id            = "${alicloud_vpc.demo_vpc.id}"
  cidr_block        = "${var.demo-untrust-vswitch-cidr}"
  availability_zone = "${data.alicloud_zones.zone.zones.0.id}"
  description       = "VSwitch for VM-series Untrust interface"
  depends_on = ["alicloud_vpc.demo_vpc" ]
}
resource "alicloud_vswitch" "data-untrust-vswitch-2" {
  provider = "alicloud.provider"
  name              = "Public-VSwitch-2-${random_string.random_name_post.result}"
  vpc_id            = "${alicloud_vpc.demo_vpc.id}"
  cidr_block        = "${var.demo-untrust-vswitch-cidr-2}"
  availability_zone = "${data.alicloud_zones.zone.zones.1.id}"
  description       = "VSwitch for VM-series Untrust interface-2"
  depends_on = ["alicloud_vpc.demo_vpc" ]
}
# Create EIP For MGMT
####################################################
resource "alicloud_eip" "MGMT-EIP" {
  provider = "alicloud.provider"
  name                 = "MGMT-EIP"
  description          = "Public IP assigned to NGFW Mgmt"
  bandwidth            = "1"
  internet_charge_type = "PayByTraffic"
}

resource "alicloud_eip" "MGMT-EIP-2" {
  provider = "alicloud.provider"
  name                 = "MGMT-EIP-2"
  description          = "Public IP assigned to NGFW Mgmt-backup"
  bandwidth            = "1"
  internet_charge_type = "PayByTraffic"
}
resource "alicloud_eip" "UNTRUST-EIP" {
  provider = "alicloud.provider"
  name                 = "UNTRUST-EIP"
  description          = "Public IP assigned to NGFW Untrust interface"
  bandwidth            = "1"
  internet_charge_type = "PayByTraffic"

  depends_on = ["module.fw_deployment"]
}


# Create Security Group 
####################################################
resource "alicloud_security_group" "MGMT-SG" {
  provider = "alicloud.provider"
  name        = "Mgmt-Security-Group"
  vpc_id      = "${alicloud_vpc.demo_vpc.id}"
  description = "Security Group for Mgmt"
}

resource "alicloud_security_group" "TRUST-SG" {
  provider = "alicloud.provider"
  name        = "Trust-Security-Group"
  vpc_id      = "${alicloud_vpc.demo_vpc.id}"
  description = "Security Group for Trust"
}

resource "alicloud_security_group" "UNTRUST-SG" {
  provider = "alicloud.provider"
  name        = "Untrust-Security-Group"
  vpc_id      = "${alicloud_vpc.demo_vpc.id}"
  description = "Security Group for Untrust"
}

# Add rules to Security Group 
####################################################
resource "alicloud_security_group_rule" "allow_all_icmp" {
  provider = "alicloud.provider"
  type              = "ingress"
  ip_protocol       = "icmp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "-1/-1"
  priority          = 1
  security_group_id = "${alicloud_security_group.MGMT-SG.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_all_443" {
  provider = "alicloud.provider"
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "443/443"
  priority          = 1
  security_group_id = "${alicloud_security_group.MGMT-SG.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_tcp_trust_all" {
  provider = "alicloud.provider"
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 100
  security_group_id = "${alicloud_security_group.TRUST-SG.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_tcp_untrust_all" {
  provider = "alicloud.provider"
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = "${alicloud_security_group.UNTRUST-SG.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_tcp__mgmt_22" {
  provider = "alicloud.provider"
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = "${alicloud_security_group.MGMT-SG.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_instance" "webserver-1" {
  provider              = "alicloud.provider"
  image_id              = "${var.image-webserver1-id}"
  instance_type         = "${var.webserver_instance_type}"
  system_disk_size      = 40
  system_disk_category  = "cloud_efficiency"
  security_groups       = ["${alicloud_security_group.TRUST-SG.id}"]
  instance_name         = "webserver-1-${random_string.random_name_post.result}"
  vswitch_id            = "${alicloud_vswitch.data-trust-vswitch.id}"
  private_ip            = "${var.web-server-1}"
  host_name             = "webserver-1"
  description           = "webserver-1"
  security_enhancement_strategy = "Active"
  instance_charge_type  = "PostPaid"
}

resource "alicloud_instance" "webserver-2" {
  provider              = "alicloud.provider"
  image_id              = "${var.image-webserver2-id}"
  instance_type         = "${var.webserver_instance_type}"
  system_disk_size      = 40
  system_disk_category  = "cloud_efficiency"
  security_groups       = ["${alicloud_security_group.TRUST-SG.id}"]
  instance_name         = "webserver-2-${random_string.random_name_post.result}"
  vswitch_id            = "${alicloud_vswitch.data-trust-vswitch-2.id}"
  private_ip            = "${var.web-server-2}"
  host_name             = "webserver-2"
  description           = "webserver-2"
  security_enhancement_strategy = "Active"
  instance_charge_type  = "PostPaid"
}



module "slb" {
  source  = "alibaba/slb/alicloud"
  version = "1.6.1"
  name = "internal-slb-${random_string.random_name_post.result}"
  profile = var.profile
  address_type = "intranet"
  master_zone_id = "${data.alicloud_zones.zone.zones.0.id}"
  region = var.region
  slave_zone_id = "${data.alicloud_zones.zone.zones.1.id}"
  spec = "slb.s1.small"
  vswitch_id    = "${alicloud_vswitch.data-trust-vswitch.id}"
  servers_of_virtual_server_group = [
    {
      server_ids = "${alicloud_instance.webserver-1.id}, ${alicloud_instance.webserver-2.id}"
      port       = "80"
      weight     = "50"
      type       = "ecs"
    },
  ]
}


resource "alicloud_slb_listener" "default" {
  provider              = "alicloud.provider"
  load_balancer_id          = "${module.slb.this_slb_id}"
  server_group_id           = "${module.slb.this_slb_virtual_server_group_id}"
  bandwidth                 = 10
  backend_port              = 80
  frontend_port             = 80
  protocol                  = "http"
  health_check              = "on"
  health_check_uri          = "/"
  health_check_connect_port = 80
  healthy_threshold         = 8
  unhealthy_threshold       = 8
  health_check_timeout      = 8
  health_check_interval     = 5
}

resource "null_resource" "update_config" {
  provisioner "local-exec" {
    command = "python3 ./change_passwd.py"
  }

  depends_on = [
    module.fw_deployment
  ]
}

data "external" "apikey" {
  program = [
    "bash",
    "./script/get_fw_key.sh"
  ]

  query = {
    eip         = "${alicloud_eip.MGMT-EIP.ip_address}"
    username    = "${var.username}"
    password    = "${var.new_password}"
  }
  depends_on = [null_resource.update_config]
}
####################################################################
#Calling the deployment modules for the VM-Series 
####################################################################

module "fw_deployment" {
  source                = "./modules/fw_deployment/"

  fwimage_pri                           = "${var.image-pri-name}"
  fwimageid_pri                         = "${var.image-pri-id}"
  fwimage_bak                           = "${var.image-bak-name}"
  fwimageid_bak                         = "${var.image-bak-id}"  
  instancetype                      = "${var.vm-series_instance_type}"
  alicloud_security_group-MGMT-SG = "${alicloud_security_group.MGMT-SG.id}"
  name                            = "${var.name}"
  name-2                          = "${var.name-2}"
  mgmt-vswitchid                 = "${alicloud_vswitch.mgmt-vswitch.id}"
  mgmt-vswitch-2id               = "${alicloud_vswitch.mgmt-vswitch-2.id}"
  alicloud_eip-MGMT-EIPid         = "${alicloud_eip.MGMT-EIP.id}"
  alicloud_eip-MGMT-EIP-2id       = "${alicloud_eip.MGMT-EIP-2.id}"
  mgmtip                         = "${var.mgmt-ip}"
  mgmt-2ip                       = "${var.mgmt-ip-2}"
  data-trust-vswitchid           = "${alicloud_vswitch.data-trust-vswitch.id}"
  data-trust-vswitch-2id         = "${alicloud_vswitch.data-trust-vswitch-2.id}"
  TRUST-SGid                     = "${alicloud_security_group.TRUST-SG.id}"
  trustip                        = "${var.trust-ip}"
  trust-2ip                      = "${var.trust-ip-2}"
  data-untrust-vswitchid         = "${alicloud_vswitch.data-untrust-vswitch.id}"
  data-untrust-vswitch-2id       = "${alicloud_vswitch.data-untrust-vswitch-2.id}"
  UNTRUST-SGid                   = "${alicloud_security_group.UNTRUST-SG.id}"
  untrustip                      = "${var.untrust-ip}"
  untrust-2ip                    = "${var.untrust-ip-2}"
  access_key                        = "${var.access_key}"
  secret_key                        = "${var.secret_key}"
  region                            = "${var.region}"
  route_table_id                    = "${alicloud_vpc.demo_vpc.route_table_id}"
  default_egress_route              = "${var.default_egress_route}"
  random                            = "${random_string.random_name_post.result}"

}

//Create the Function Service
resource "alicloud_fc_service" "paloalto-failover-service" {
  provider = "alicloud.provider"
  depends_on = [alicloud_ram_role.ram_role]
  name = "HA_Function_Service-${random_string.random_name_post.result}" 
  description = "Created by terraform"
  internet_access = true
  role = alicloud_ram_role.ram_role.arn

}
resource "alicloud_fc_function" "active-standby" {
  provider = "alicloud.provider"
  service     = alicloud_fc_service.paloalto-failover-service.name
  name        = "paloalto-failover-service-${random_string.random_name_post.result}"
  description = "Palo Alto Active Standby - AliCloud Created by Terraform"
  filename    = "./func/index.zip"
  memory_size = "128"
  runtime     = "python3"
  handler     = "index.handler"
  timeout     = "60"
  environment_variables = {
    managedby = "Created by Mason Yan and Daniel Ma"
    API_KEY   = "${data.external.apikey.result.api_key}"
    BACKUP_ENI = "${module.fw_deployment.trust-interface-bak}"
    PRIMARY_ENI = "${module.fw_deployment.trust-interface-pri}"
    PUB_BAK_ENI = "${module.fw_deployment.untrust-interface-bak}"
    PUB_PRI_ENI = "${module.fw_deployment.untrust-interface-pri}"
    EIP         = "${alicloud_eip.UNTRUST-EIP.ip_address}"
    EIP_ID      = "${alicloud_eip.UNTRUST-EIP.id}"
    PRIMARYNGFWMGMT_IP = "${alicloud_eip.MGMT-EIP.ip_address}"
    REGION_ID   = "${var.region}"
    ROUTETB_ID  = "${alicloud_vpc.demo_vpc.route_table_id}"
  }
}

//Function Compute Trigger
resource "alicloud_fc_trigger" "timer" {
  provider = "alicloud.provider"
  service  = alicloud_fc_service.paloalto-failover-service.name
  function = alicloud_fc_function.active-standby.name
  name     = "CronTrigger"
  type     = "timer"
  config   = <<EOF
{

            "cronExpression": "@every 1m",
            "enable": true
        }

EOF

}



resource "alicloud_ram_role" "ram_role" {
  provider = "alicloud.provider"
  name     = "FunctionCompute-RAM-Role-${random_string.random_name_post.result}"
  document = <<EOF
{
"Statement": [
    {
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": {
        "Service": [
            "fc.aliyuncs.com"
        ]
    }
    }
],
"Version": "1"
}
EOF
  description = "FunctionCompute-RAM-Role."
  force = true
}


resource "alicloud_ram_policy" "policy" {
  provider = "alicloud.provider"
  name = "RAM-Policy-${random_string.random_name_post.result}"
  document = <<EOF
{
"Statement": [

    {
    "Action": "ecs:*", 
    "Resource": "*", 
    "Effect": "Allow"
    }, 
    {
    "Action": [
    "vpc:DescribeVpcs", 
    "vpc:DescribeVSwitches"
    ], 
    "Resource": "*", 
    "Effect": "Allow"
    },

    {
    "Action": [
        "vpc:*HaVip*", 
        "vpc:*RouteTable*", 
        "vpc:*VRouter*", 
        "vpc:*RouteEntry*", 
        "vpc:*VSwitch*", 
        "vpc:*Vpc*", 
        "vpc:*Cen*", 
        "vpc:*Tag*", 
        "vpc:*NetworkAcl*"
    ], 
    "Resource": "*", 
    "Effect": "Allow"
    },

    {
    "Action": [
        "vpc:*Eip*", 
        "vpc:*HighDefinitionMonitor*"
    ], 
    "Resource": "*", 
    "Effect": "Allow"
    }, 
    {
    "Action": "ecs:DescribeInstances", 
    "Resource": "*", 
    "Effect": "Allow"
    },

    {
    "Action": [
        "vpc:DescribeVSwitchAttributes"
    ], 
    "Resource": "*", 
    "Effect": "Allow"
    }, 
    {
    "Action": [
        "ecs:CreateNetworkInterface", 
        "ecs:DeleteNetworkInterface", 
        "ecs:DescribeNetworkInterfaces", 
        "ecs:CreateNetworkInterfacePermission", 
        "ecs:DescribeNetworkInterfacePermissions", 
        "ecs:DeleteNetworkInterfacePermission"
    ], 
    "Resource": "*", 
    "Effect": "Allow"
    }
],

"Version": "1"
}
EOF
  description = "FunctionCompute-RAM-Role."
  force = true
}

resource "alicloud_ram_role_policy_attachment" "attach" {
  provider = "alicloud.provider"
  policy_name = alicloud_ram_policy.policy.name
  policy_type = alicloud_ram_policy.policy.type
  role_name = alicloud_ram_role.ram_role.name
}









