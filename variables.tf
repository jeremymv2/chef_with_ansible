////////////////////////////////
// Required variables. Create a terraform.tfvars.

variable "aws_key_pair_name" {
  description = "The name of the key pair to associate with your instances. Required for SSH access."
}

variable "aws_key_pair_file" {
  description = "The path to the file on disk for the private key associated with the AWS key pair associated with your instances. Required for SSH access."
}

variable "tag_dept" {
  description = "The department at your company responsible for these resources."
}

variable "tag_contact" {
  description = "The email address associated with the person or team that is standing up this resource. Used to contact if problems occur."
}

////////////////////////////////
// AWS

variable "count_num" {
  default     = 2
  description = "The number of instances to provision."
}

variable "aws_region" {
  default     = "us-west-2"
  description = "The name of the selected AWS region / datacenter."
}

variable "aws_profile" {
  default     = "default"
  description = "The AWS profile to use from your ~/.aws/credentials file."
}

variable "aws_vpc" {
  default     = "vpc-41d45124"
  description = "The VPC resources will be created under."
}

variable "aws_subnet" {
  default     = "subnet-7424b611"
  description = "The subnet resources will be created under."
}

variable "default_security_group" {
  default     = "sg-c9beb2ac"
  description = "The security group resources will be created under."
}

variable "aws_ami_user" {
  default     = "centos"
  description = "The user used for SSH connections and path variables."
}

variable "aws_ami_id" {
  default     = ""
  description = "The AMI id to use for the base image for instances. Leave blank to auto-select the latest high performance CentOS 7 image."
}

variable "tag_name" {
  default     = ["mynode1", "mynode2"]
  description = "An array of instance names, for each instance created. Appears in the AWS UI for identifying instances."
}

variable "aws_instance_types" {
  default     = ["t3.medium", "t3.medium"]
  description = "An array of instance types (sizes). tag_name indicates which instances map to which type."
}

////////////////////////////////
// Role and other DNA

variable "instance_role" {
  default     = ["iamfrontend", "iambackend"]
  description = "An array of instance roles."
}

////////////////////////////////
// Chef

variable "cookbook_name" {
  default     = ""
  description = "The name of the cookbook under the `cookbook` directory."
}

variable "run_list" {
  default     = ""
  description = "A fully qualified run_list. ie. `my_cookbook::default`"
}

variable "chef_version" {
  default     = ""
  description = "The version of Chef Client to install."
}

variable "backend_ip" {
  default     = ""
  description = "The public IP address of the Backend node"
}

variable "frontend_ip" {
  default     = ""
  description = "The public IP address of the Frontend node"
}

////////////////////////////////
// Ansible

variable "ansible_playbook" {
  default     = ""
  description = "The Playbook to execute"
}

variable "ansible_timeout" {
  default     = "20"
  description = "Transport timeout for each ssh attempt."
}

variable "ansible_host_key_checking" {
  default     = "false"
  description = "Check ssh host key true|false"
}

variable "ansible_ssh_retries" {
  default     = "6"
  description = "Transport ssh retry attempts."
}

variable "ansible_var_sysctl_vm_swappiness" {
  default     = "60"
  description = "vm.swappiness setting in sysctl"
}
