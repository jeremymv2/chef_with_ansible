# # encoding: utf-8

# Once suite of Inspec tests to run against Terraform nodes provisioned with
# both Ansible + Chef.

# The Inspec reference, with examples and extensive documentation, can be
# found at http://inspec.io/docs/reference/resources/

val_frontend_server_public_ip = attribute('frontend_server_public_ip', default: '', description: 'Public IP for Frontend')
val_backend_server_public_ip = attribute('backend_server_public_ip', default: '', description: 'Public IP for Backend')

control 'terraform inventory' do
  impact 0.6
  title 'Terraform State Metadata'
  desc '
    Ensure what we wanted is what we got.
  '
  describe 'each aws_instance' do
    subject { file('/tmp/NODES') }
    it 'should have all node inventory knowledge from Terraform' do
      expect((subject).content).to match(/#{val_frontend_server_public_ip}/)
      expect((subject).content).to match(/#{val_backend_server_public_ip}/)
    end
  end
end

control 'role frontend' do
  impact 0.6
  title 'Terraform Frontend Role Metadata'
  desc '
    Ensure Frontend role info is applied correctly.
  '
  describe 'the frontend aws_instance' do
    subject { file('/etc/dna.toml') }
    it 'should have its role knowledge from Terraform' do
      expect((subject).content).to match(/iamfrontend/)
    end
  end
end

control 'role backend' do
  impact 0.6
  title 'Terraform Backend Role Metadata'
  desc '
    Ensure Backend role info is applied correctly.
  '
  describe 'the backend aws_instance' do
    subject { file('/etc/dna.toml') }
    it 'should have its role knowledge from Terraform' do
      expect((subject).content).to match(/iambackend/)
    end
  end
end
