terraform {
  required_version = ">= 0.11.0"
}

data "template_file" "chef_solo_json" {
  template = "${file("${path.module}/solojson.tpl")}"
  vars {
    frontend_ip = "${aws_instance.myapp_cluster.*.public_ip[0]}"
    backend_ip = "${aws_instance.myapp_cluster.*.public_ip[1]}"
    run_list = "${var.run_list}"
  }
}

data "template_file" "ansible_inventory" {
  template = "${file("${path.module}/inventory.tpl")}"

  vars {
    frontend_ip = "${aws_instance.myapp_cluster.*.public_ip[0]}"
    backend_ip = "${aws_instance.myapp_cluster.*.public_ip[1]}"
    key_path = "${var.aws_key_pair_file}"
    user = "${var.aws_ami_user}"
  }
}

provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

resource "random_id" "instance" {
  byte_length = 4
}

data "aws_ami" "centos" {
  most_recent = true
  owners      = ["446539779517"]

  filter {
    name   = "name"
    values = ["chef-highperf-centos7-*"]
  }
}

resource "aws_instance" "myapp_cluster" {
  count = 2

  # We execute this resource twice, creating two aws_instances. We can reference each instance via count.index
  # For example: aws_instance.myapp_cluster.*.public_dns[count.index]
  # count.index will be one of:
  # 0 == MyApp Frontend
  # 1 == MyApp Backend
  # The advantage of this is two-fold:
  #  1. we do not need duplicated provisioner blocks for each
  #  2. the provisioner blocks will execute in parallel - this cuts provisioning times roughly in half

  connection {
    user        = "${var.aws_ami_user}"
    private_key = "${file("${var.aws_key_pair_file}")}"
  }

  ami                         = "${var.aws_ami_id == "" ? data.aws_ami.centos.id : var.aws_ami_id}"
  instance_type               = "${element(var.aws_instance_types, count.index)}"
  key_name                    = "${var.aws_key_pair_name}"
  subnet_id                   = "${var.aws_subnet}"
  vpc_security_group_ids      = ["${var.default_security_group}"]
  associate_public_ip_address = true
  ebs_optimized               = true
  root_block_device {
    delete_on_termination = true
    volume_size           = 200
    volume_type           = "gp2"
  }
  tags {
    Name      = "example-${element(var.tag_name, count.index)}-${random_id.instance.hex}"
    X-Dept    = "${var.tag_dept}"
    X-Contact = "${var.tag_contact}"
  }
}

resource "null_resource" "provision_cluster" {
  count = 2

  # We execute resource twice, once for each node. See resource "aws_instance" notes above.
  # Each time we run Ansible first, then Chef!

  connection {
    user        = "${var.aws_ami_user}"
    private_key = "${file("${var.aws_key_pair_file}")}"
    host        = "${aws_instance.myapp_cluster.*.public_dns[count.index]}"
  }

  ## Ansible tasks

  triggers {
    template = "${data.template_file.ansible_inventory.rendered}"
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.ansible_inventory.rendered}' > inventory"
  }

  provisioner "local-exec" {
    environment {
      ANSIBLE_HOST_KEY_CHECKING = "false"
      ANSIBLE_TIMEOUT = 20
      ANSIBLE_SSH_RETRIES = 6
    }
    command = "ansible-playbook -i inventory ${path.module}/playbook/doit.yml"
  }

  ## Chef cookbooks

  triggers {
    template = "${data.template_file.chef_solo_json.rendered}"
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/cookbook/${var.cookbook_name}"
    command = "rm -f cookbooks*gz"
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/cookbook/${var.cookbook_name}"
    command = "berks package --berksfile=./Berksfile && cp -f $(ls -1t cookbooks-*.tar.gz | head -1) cookbooks.tar.gz"
  }

  provisioner "file" {
    source      = "${path.module}/cookbook/${var.cookbook_name}/cookbooks.tar.gz"
    destination = "/tmp/cookbooks.tar.gz"
  }

  provisioner "file" {
    content = "${data.template_file.chef_solo_json.rendered}"
    destination = "/tmp/solo.json"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -v ${var.chef_version}",
      "sudo chef-solo --recipe-url /tmp/cookbooks.tar.gz -j /tmp/solo.json"
    ]
  }
}
