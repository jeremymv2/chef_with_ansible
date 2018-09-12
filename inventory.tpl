[backend]
${backend_ip}

[frontend]
${frontend_ip}

[all:vars]
ansible_ssh_private_key_file = ${key_path}
ansible_ssh_user = ${user}
ansible_become = true
