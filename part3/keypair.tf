resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "my-ec2-keypair"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "local_file" "ssh_key" {
  filename        = "ec2-keypair.pem"
  content         = tls_private_key.ec2_key.private_key_pem
  file_permission = "0400"
}
