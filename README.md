# Introduction

This is Developed by Mason Yan and Daniel Ma from Palo Alto Networks. This is a Demo package to install two VM series NGFW and two nginx servers for HA function on AliCloud. Now you can use this but has not been fully tested and supported. Please use or modify it at your own discretion and after sufficient testing.. 


# Requirements

To deploy this template, a RAM user with an AccessKey and Secret are required. This user will need access to ECS, VPC, RAM, and FC. For details on creating a RAM user, refer to the AliCloud article [Create a RAM user](https://www.alibabacloud.com/help/doc-detail/28637.htm).
You need to have below installed: 
1. Terraform v0.12
2. Python 3.8
3. expect
4. jq

Install neccesary Python Lib: 
pip3 install -r requirements.txt

# Deployment Overview

The Terraform script will create the following:

- A Function Compute service and one function:
  - A timer function that runs once per minute to check VM NGFW healthy status and move to standby NGFW when Primary NGFW has problem. And when the Primary NGFW back to normal, swicthing back.
- An AliCloud RAM policy for Function Compute service to perform VPC, ECS changes
- A Virtual Private Cloud (VPC)
- Three security groups, management, trust and untrust
- Three vswitches
- A default route to Primary NGFW
- Two VM series NGFW in separate AZs
- Two nginx servers running in trust vswitches

The Terraform deployment below architecture:
![image](https://github.com/danielma911/Alicloud_VM_HA/blob/master/imgs/Architecture_in.png)
![image](https://github.com/danielma911/Alicloud_VM_HA/blob/master/imgs/Architecture_out.png)
![image](https://github.com/danielma911/Alicloud_VM_HA/blob/master/imgs/Monitoring.png)
![image](https://github.com/danielma911/Alicloud_VM_HA/blob/master/imgs/Switching_standby_in.png)
![image](https://github.com/danielma911/Alicloud_VM_HA/blob/master/imgs/Switching_standby_out.png)

# Deployment
1. Update the VM-series_vars.tf with correct information, like the ASAK, image name, region etc. Or you can provide those info with "terraform apply -var access_key="<access_key>" -var secret_key="<secret_key>"
2. terraform init
3. terraform apply
4. Demo infra will be deployed, you will see at some point the progress seems stuck. No worry, it is because the terraform is waiting for the NGFW comming up and get the API_Key. Just take a rest and grab a coffee, it takes about 5-10 mins to setup full environmnt.

5. When finished, it will shows up necessary info for you to continue:

    Outputs Expamples:

    SLB-IP-Address = 10.0.6.82

    VM-Series-MGMTIP = 47.242.129.211

    VM-Series-MGMTIP-2 = 47.242.92.207

    VM-Series-UNTRUSTIP = 8.210.183.24 *** Please manually attach this IP to Untrust ENI. ***


6. In folder FW_config, go into each ngfw sub-folder to update the SLB-IP-Address, and management IP address from the outputs "VM-Series-MGMTIP", "VM-Series-MGMTIP-2" "SLB-IP-Address" for both NGFW. Run: terraform init; terraform apply; accordingly. This will configure the NGFW with interface address, Zones, NAT policy and security policy necessary for the demo environment. Auto Commit is enabled, you DO NOT need to manually go into console and commit.


7. Licensing both the Primary and Standby NGFW

8. Important: attach the Untrust EIP "VM-Series-UNTRUSTIP" to the Primary NGFW untrust ENI. 

9. Now you are ready to go.

# Uninstall

1. Unbind the EIP "VM-Series-UNTRUSTIP" from the NGFW untrust interface[important]

2. Run "terraform destroy"

# Support

Pls. contact with dma@paloaltonetworks.com or myan@paloaltonetworks.com
