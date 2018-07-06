#####
# Output
#####

output "ssh_user" {
  description = "SSH user to download kubeconfig file"
  value       = "centos"
}

output "public_ip" {
  description = "Cluster IP address"
  value       = "${aws_eip.master.public_ip}"
}

output "private_ip" {
  description = "Cluster private IP address"
  value       = "${aws_instance.master.private_ip}"
}

output "dns" {
  description = "Cluster DNS address"
  value       = "${aws_route53_record.master.fqdn}"
}

output "autoscaling_group_name" {
  description = "Cluster nodes autoscaling group name"
  value       = "${aws_autoscaling_group.nodes.name}"
}

output "kubeconfig_security_group" {
  description = "Kubernetes Security Group"
  value       = "${aws_security_group.kubernetes.id}"
}

output "kubeconfig_dns" {
  description = "Path to the the kubeconfig file using DNS address"
  value       = "/home/centos/kubeconfig"
}

output "kubeconfig_ip" {
  description = "Path to the kubeconfig file using IP address"
  value       = "/home/centos/kubeconfig_ip"
}
