# :musical_note: Harmonizing your Automation with Terraform, Ansible, Chef and InSpec. :musical_note:

## Overview

Do you have pockets of Ansible and Chef in your organization?

Maybe you feel that Ansible is best suited for a particular task, whereas you also have a mature
Chef cookbook base that is well suited for other tasks.

Are you considering if you should consolidate on just one automation tool? Perhaps you are concerned
about how you would adequately test automation that utilized _both_ Chef and Ansible together.

This repository demonstrates how to provision multinode infrastructure deployments using Terraform,
Ansible and Chef together in one, multi-phased process. When provisioning is complete, the
infrastructure will be verified by an InSpec profile that tests all the systems holistically, in one run :tada:

The result is lean and efficient Automation leveraging what you already have on hand in your organization.

An **important** concept that allows this careful balance and harmony of tools is to house all the Automation
for a specific App in the _same_ repository in source control. Any change triggers CI to exercise and test the
entire suite.

![pipeline](https://raw.githubusercontent.com/jeremymv2/chef_with_ansible/master/harmony.png)

## The Phases

The automation will be controlled by [kitchen-terraform](https://github.com/newcontext-oss/kitchen-terraform) allowing you
complete control and flexibility by virtue of powerful Terraform provisioning. An InSpec verifier (supplied with `kitchen-terraform`) ties
into the Terraform state allowing you to leverage Terraform metadata.

`kitchen-terraform` brilliantly helps smooth over the age-old very rough edges that Test Kitchen has for provisioning
and testing multi-node deployments.

The phases that will run in one execution of `kitchen test` are:
1. Provision Infrastructure with Terraform Plans
2. Run Ansible Playbooks
3. Converge with Chef Cookbooks
5. Verify with InSpec Controls

## Meta-Data Discovery

An additional benefit that Terraform provides is rudimentary "Service Discovery" by virtue
of being able to share meta-data in files between nodes. This allows Ansible and Chef to leverage this
data during node configuration.

## Testing it out

Review the Terraform Plan _defaults_ in `variables.tf` and provide overrides as needed in `terraform.tfvars`.

Spin it all up! This will run through _all_ the Phases listed above:

```
kitchen test
```

### DNA

Give each node a programatically determined role and store on the node's filesystem so that Ansible
and Chef can configure the node accordingly.

```
  4 # Each node gets a DNA file to designate its role
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
 24       # we can also specify which controls run on each node
 25       controls:
 26         - role frontend
 27         - terraform inventory
 28     - name: Backend
 29       backend: ssh
 30       user: centos
 31       show_progress: true
 32       key_files:
 33         - /Users/jmiller/.ssh/jmiller
 34       hosts_output: backend_server_public_dns
 35       sudo: true
 36       attrs_outputs:
 37         frontend_server_public_ip: frontend_server_public_ip
 38         backend_server_public_ip: backend_server_public_ip
 39       controls:
 40         - role backend
 41         - terraform inventory
```

There is an existing Terraform integration via the `kitchen-terraform` [InSpec Verifier](https://www.rubydoc.info/github/newcontext-oss/kitchen-terraform/Kitchen/Verifier/Terraform)

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
  6 # The Inspec reference, with examples and extensive documentation, can be
  7 # found at http://inspec.io/docs/reference/resources/
  8
  9 val_frontend_server_public_ip = attribute('frontend_server_public_ip', default: '', description: 'Public IP for Frontend')
 10 val_backend_server_public_ip = attribute('backend_server_public_ip', default: '', description: 'Public IP for Backend')
 11
 12 control 'terraform inventory' do
 13   impact 0.6
 14   title 'Terraform State Metadata'
 15   desc '
 16     Ensure what we wanted is what we got.
 17   '
 18   describe 'each aws_instance' do
 19     subject { file('/tmp/NODES') }
 20     it 'should have all node inventory knowledge from Terraform' do
 21       expect((subject).content).to match(/#{val_frontend_server_public_ip}/)
 22       expect((subject).content).to match(/#{val_backend_server_public_ip}/)
 23     end
 24   end
 25 end
 26
 27 control 'role frontend' do
 28   impact 0.6
 29   title 'Terraform Frontend Role Metadata'
 30   desc '
 31     Ensure Frontend role info is applied correctly.
 32   '
 33   describe 'the frontend aws_instance' do
 34     subject { file('/etc/dna.toml') }
 35     it 'should have its role knowledge from Terraform' do
 36       expect((subject).content).to match(/iamfrontend/)
 37     end
 38   end
 39 end
 40
 41 control 'role backend' do
 42   impact 0.6
 43   title 'Terraform Backend Role Metadata'
 44   desc '
 45     Ensure Backend role info is applied correctly.
 46   '
 47   describe 'the backend aws_instance' do
 48     subject { file('/etc/dna.toml') }
 49     it 'should have its role knowledge from Terraform' do
 50       expect((subject).content).to match(/iambackend/)
 51     end
 52   end
 53 end
```

![pipeline](https://raw.githubusercontent.com/jeremymv2/chef_with_ansible/master/inspec.png)
