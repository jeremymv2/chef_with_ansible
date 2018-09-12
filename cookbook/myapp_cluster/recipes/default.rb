#
# Cookbook:: cookbook_with_ansible
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

file '/tmp/CHEF' do
  content 'Chef was here!'
end

file '/tmp/NODES' do
  content "Backend #{node['myapp_cluster']['backend_ip']}\nFrontend #{node['myapp_cluster']['frontend_ip']}"
end
