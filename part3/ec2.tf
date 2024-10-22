resource "aws_instance" "ec2_instance" {
  ami             = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.allow_ssh.name]

  user_data = <<-EOF
  #!/bin/bash
  sudo yum update -y
  sudo amazon-linux-extras install docker -y
  sudo service docker start
  sudo usermod -aG docker ec2-user
  EOF


  tags = {
    Name      = "Docker-EC2-Instance"
    CreatedBy = "Terraform"
    Module    = "SR Part 3"
    Version   = "42"
  }

}
