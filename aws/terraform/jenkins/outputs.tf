output "jenkins_instance_id" {
  description = "ID of the Jenkins EC2 instance"
  value       = aws_instance.jenkins.id
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins instance"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_private_ip" {
  description = "Private IP of the Jenkins instance"
  value       = aws_instance.jenkins.private_ip
}

output "jenkins_public_dns" {
  description = "Public DNS name of the Jenkins instance"
  value       = aws_instance.jenkins.public_dns
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_security_group_id" {
  description = "ID of the Jenkins security group"
  value       = aws_security_group.jenkins.id
}

output "jenkins_role_arn" {
  description = "ARN of the Jenkins IAM role"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_eip" {
  description = "Elastic IP associated with Jenkins (if allocated)"
  value       = var.allocate_eip ? aws_eip.jenkins[0].public_ip : null
}

output "ssh_command" {
  description = "SSH command to connect to Jenkins instance"
  value       = "ssh -i <your-key-file.pem> ubuntu@${aws_instance.jenkins.public_ip}"
}