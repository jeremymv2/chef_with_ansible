# # encoding: utf-8

# Once suite of Inspec tests to run against Terraform nodes provisioned with
# _both_ Ansible + Chef!!

# The Inspec reference, with examples and extensive documentation, can be
# found at http://inspec.io/docs/reference/resources/

val_frontend_server_public_ip = attribute('frontend_server_public_ip', default: '', description: 'Public IP for Frontend')
val_backend_server_public_ip = attribute('backend_server_public_ip', default: '', description: 'Public IP for Backend')

describe file('/tmp/NODES') do
  its('content') { should match /#{val_frontend_server_public_ip}/ }
  its('content') { should match /#{val_backend_server_public_ip}/ }
end
