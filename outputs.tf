output "frontend_server_public_ip" {
  value = "${aws_instance.myapp_cluster.*.public_ip[0]}"
}

output "backend_server_public_ip" {
  value = "${aws_instance.myapp_cluster.*.public_ip[1]}"
}

output "frontend_server_public_dns" {
  value = "${aws_instance.myapp_cluster.*.public_dns[0]}"
}

output "backend_server_public_dns" {
  value = "${aws_instance.myapp_cluster.*.public_dns[1]}"
}

output "frontend_server_ssh" {
  value = "ssh -i ${var.aws_key_pair_file} ${var.aws_ami_user}@${aws_instance.myapp_cluster.*.public_dns[0]}"
}

output "backend_server_ssh" {
  value = "ssh -i ${var.aws_key_pair_file} ${var.aws_ami_user}@${aws_instance.myapp_cluster.*.public_dns[1]}"
}
