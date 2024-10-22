output "instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.ec2_instance.public_ip
}

output "keypair_private_key_path" {
  description = "Path to the EC2 private key file"
  value       = local_file.ssh_key.filename
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.allow_ssh.id
}
