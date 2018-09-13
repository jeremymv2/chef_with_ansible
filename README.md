# Harmonizing your Automation with Terraform, Ansible, Chef and InSpec. :musical_note:

## Overview :tophat:

Do you have pockets of Ansible and Chef in your organization? Maybe Ansible is best suited for a
particular task, whereas you already have a mature Chef cookbook base that is well suited for
other tasks.

Are you deciding if you should consolidate on just one automation tool? Perhaps you are concerned
about how you would adequately test automation that utilized _both_ Chef and Ansible together?

This repository demonstrates how to provision multinode infrastructure deployments using Terraform,
Ansible and Chef together in one, multi-phased process. When provisioning is complete, the
infrastructure will be completely verified by a holistic InSpec profile, from the same repository!

The result is lean and efficient Automation, using the best of breed tools available on hand.
Keeping a careful balance 

## The Phases :nut_and_bolt:

The automation will be controlled by [kitchen-terraform](https://github.com/newcontext-oss/kitchen-terraform) allowing you
complete control and flexibility by virtue of Terraform provisioning with an InSpec verifier that ties
into the Terraform state.

`kitchen-terraform` brilliantly solves the age-old inadequacies Test Kitchen has for provisioning
and testing multi-node deployments.

The phases implemented in this repo are roughly:
1. Provision Infrastructure with Terraform Plans
2. Run Ansible Playbooks
3. Converge with Chef Cookbooks
5. Verify with InSpec Controls

An *important* concept that allows this careful balance and harmony of tools is that all the Automation
lives in the _same_ repository in source control. Any change triggers CI to exercise and test the
entire suite.

![pipeline](https://raw.githubusercontent.com/jeremymv2/chef_with_ansible/master/harmony.png)

## Service Discovery :cyclone:

An additional benefit that Terraform brings to the table is rudimentary "Service Discovery" by virtue
of being able to share meta-data in files between nodes which Ansible and Chef can later leverage during
configuration.

## Trying it out :honey_pot:

Review the Terraform Plan _defaults_ in `variables.tf` and override as needed in `terraform.tfvars`.
Spin it all up! This will run through _all_ the Phases listed above:

```
kitchen test
```

Let's review all the important parts of the `main.tf` Terraform Plan next.

### DNA

Give each node a programatically determined role and store on the node's filesystem so that Ansible
and Chef can configure the node accordingly.

```
    ## Each node gets a DNA file to designate its role
  5 data "template_file" "system_dna" {
  6   count = "${var.count_num}"
  7   template = "${file("${path.module}/dnatoml.tpl")}"
  8   vars {
  9     role = "${element(var.instance_role, count.index)}"
 10   }
 11 }

 ...

110   ## DNA
111
112   triggers {
113     template = "${element(data.template_file.system_dna.*.rendered, count.index)}"
114   }
115
116   provisioner "file" {
117     content = "${element(data.template_file.system_dna.*.rendered, count.index)}"
118     destination = "/tmp/dna.toml"
119   }
120
121   provisioner "remote-exec" {
122     inline = [
123       "sudo cp -f /tmp/dna.toml /etc"
124     ]
125   }
```

### Ansible Plays

We arbitrarily decide to run Ansible playbooks next.

```
 25 # Create an Ansible Inventory file via template
 26 data "template_file" "ansible_inventory" {
 27   template = "${file("${path.module}/inventory.tpl")}"
 28
 29   vars {
 30     frontend_ip = "${aws_instance.myapp_cluster.*.public_ip[0]}"
 31     backend_ip = "${aws_instance.myapp_cluster.*.public_ip[1]}"
 32     key_path = "${var.aws_key_pair_file}"
 33     user = "${var.aws_ami_user}"
 34   }
 35 }

 ...

130   ## Ansible tasks
131
132   triggers {
133     template = "${data.template_file.ansible_inventory.rendered}"
134   }
135
136   triggers {
137     template = "${data.template_file.ansible_vars.rendered}"
138   }
139
140   provisioner "local-exec" {
141     command = "echo '${data.template_file.ansible_inventory.rendered}' > inventory"
142   }
143
144   provisioner "local-exec" {
145     command = "echo '${data.template_file.ansible_vars.rendered}' > ansible_vars.yml"
146   }
147
148   provisioner "local-exec" {
149     environment {
150       ANSIBLE_HOST_KEY_CHECKING = "${var.ansible_host_key_checking}"
151       ANSIBLE_TIMEOUT = "${var.ansible_timeout}"
152       ANSIBLE_SSH_RETRIES = "${var.ansible_ssh_retries}"
153     }
154     command = "ansible-playbook -i inventory --extra-vars '@${path.module}/ansible_vars.yml' ${path.module}/playbook/${var.ansible_playbook}"
155   }
```

### Chef Cookbooks

After Ansible runs, it's time to converge with the Role/Env cookbook.

```
 14 # Json file for chef-solo (run_list, override attributes)
 15 data "template_file" "chef_solo_json" {
 16   template = "${file("${path.module}/solojson.tpl")}"
 17   vars {
 18     frontend_ip = "${aws_instance.myapp_cluster.*.public_ip[0]}"
 19     backend_ip = "${aws_instance.myapp_cluster.*.public_ip[1]}"
 20     motd = "${var.run_list}"
 21     run_list = "${var.run_list}"
 22   }
 23 }

 ...

 157   ## Chef cookbooks
158
159   triggers {
160     template = "${data.template_file.chef_solo_json.rendered}"
161   }
162
163   provisioner "local-exec" {
164     working_dir = "${path.module}/cookbook/${var.cookbook_name}"
165     command = "berks package --berksfile=./Berksfile && cp -f $(ls -1t cookbooks-*.tar.gz | head -1) cookbooks.tar.gz"
166   }
167
168   provisioner "file" {
169     source      = "${path.module}/cookbook/${var.cookbook_name}/cookbooks.tar.gz"
170     destination = "/tmp/cookbooks.tar.gz"
171   }
172
173   provisioner "file" {
174     content = "${data.template_file.chef_solo_json.rendered}"
175     destination = "/tmp/solo.json"
176   }
177
178   provisioner "remote-exec" {
179     inline = [
180       "curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -v ${var.chef_version}",
181       "sudo chef-solo --recipe-url /tmp/cookbooks.tar.gz -j /tmp/solo.json"
182     ]
183   }
```


### InSpec Verification

After all the above steps complete, `kitchen-terraform` can run the InSpec controls that verify
the changes made by Ansible and Chef are as intended.

The `.kitchen.yml` file contains the important parts that allow this to happen:

```
 10 verifier:
 11   name: terraform
 12   systems:
 13     - name: Frontend
 14       backend: ssh
 15       user: centos
 16       show_progress: true
 17       key_files:
 18         - /Users/jmiller/.ssh/jmiller
 19       hosts_output: frontend_server_public_dns
 20       sudo: true
 21       attrs_outputs:
 22         frontend_server_public_ip: frontend_server_public_ip
 23         backend_server_public_ip: backend_server_public_ip
 24     - name: Backend
 25       backend: ssh
 26       user: centos
 27       show_progress: true
 28       key_files:
 29         - /Users/jmiller/.ssh/jmiller
 30       hosts_output: backend_server_public_dns
 31       sudo: true
 32       attrs_outputs:
 33         frontend_server_public_ip: frontend_server_public_ip
 34         backend_server_public_ip: backend_server_public_ip
```

There is seamless integration via the `kitchen-terraform` [InSpec Verifier](https://www.rubydoc.info/github/newcontext-oss/kitchen-terraform/Kitchen/Verifier/Terraform)

InSpec can leverage data from Terraform `outputs.tf` to discover the Node's meta data from the Terraform State.
We use this to dynamically discover the Node IP addresses to use for the scan.

Also, we can create arbitrary InSpec Attributes from outputs in `outputs.tf`:

```
  1 output "frontend_server_public_ip" {
  2   value = "${aws_instance.myapp_cluster.*.public_ip[0]}"
  3 }
  4
  5 output "backend_server_public_ip" {
  6   value = "${aws_instance.myapp_cluster.*.public_ip[1]}"
  7 }
  8
  9 output "frontend_server_public_dns" {
 10   value = "${aws_instance.myapp_cluster.*.public_dns[0]}"
 11 }
 12
 13 output "backend_server_public_dns" {
 14   value = "${aws_instance.myapp_cluster.*.public_dns[1]}"
 15 }
```

And then leverage the Attributes in our controls:

```

```

![pipeline](https://raw.githubusercontent.com/jeremymv2/chef_with_ansible/master/inspec.jpg)
