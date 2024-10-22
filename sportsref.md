# Docker (Part 1)

1. Create a Dockerfile that produces a Docker image that, when run as a container, outputs the external IP of the container/host and then exits

I want to say that the wording is a bit confusing, but I'll assume
that it means the external IP of the host by making a curl connection
to a system that reports that external IP address. On my local
machine that would be the external IP address on my router, which
I'll obtain it by making a curl request to `https://ifconfig.me.`

```Dockerfile
<<part1/docker.dockerfile>>=
FROM alpine:3.18
RUN apk add --no-cache curl
ENTRYPOINT ["/bin/sh", "-c", "curl -s https://ifconfig.me"]
@
```

`ip -4 -o address | sed -ne 's/.*eth.*inet *\(.*\)\/.*brd.*/\1/p'` will get 
your container IP address. 

# Docker Compose (Part 2)

1. Create a Dockerfile that produces a Docker image that runs Apache but listens on port 8888 instead of port 80
2. Create a docker-compose.yml that utilizes the previously created image to serve an index.html file that simply says, "We democratize data, so our users enjoy, understand, and share the sports they love."
3. Configure the docker-compose.yml so that changing the content of the index.html file and reloading the browser should show an updated text string without restarting any containers

### Question 1

The wording is, again, a bit confusing. It is difficult to say if the
question is asking that the Apache server should listen on port 8888
in the DOCKER container or that it answers on port 8888 on the HOST
and the port that Apache runs on in the container is irrelevant.

I will assume that the port that the Apache server listens on is 
not critical, but will include an example of how you could 
run Apache on port 8888 in the container.

"`Dockerfile
<<part2/apache.dockerfile>>=
FROM httpd:2.4
ENTRYPOINT ["/usr/local/apache2/bin/httpd", "-D", "FOREGROUND"]
@

Build and run the Docker container with the following commands:
"`shell
<<run-apache-docker>>=
dac -t -R apache8888.dockerfile docker-compose.md | \
docker build -t docker:srtest2 -f - .
docker run -p 8888:80 docker:srtest2 
@
```

````Dockerfile
<<part2/apache8888.dockerfile>>=
FROM httpd:2.4
ENTRYPOINT ["/usr/local/apache2/bin/apachectl", "-D", "FOREGROUND", "-D", "HTTP_PORT=8888"]
@
```

Build and run the Docker container with the following commands:
"`shell
<<run-apache8888-docker>>=
dac -t -R apache8888.dockerfile docker-compose.md | \
docker build -t docker8888:srtest2 -f - .
docker run -p 8888:8888 docker8888:srtest2 
@
```

The second example will run Apache on port 8888 in the container, but
there is little benefit to doing so. The first example is the one I  
will use in the rest of the solution.

### Question 2

Create a `docker-compose.yml` that utilizes the previously 
created image to serve an index.html file that simply says 
"We democratize data, so our users enjoy, understand, and share 
the sports they love."

We will want `index.html` to be updated in the container when it is
update in the host.

There are a few ways to approach this. First, we can build the
docker container locally and store it in the host docker repository. 

We can also update the docker container to a remote ECR repository 
and have docker-compose pull the image from the repository.

Here, since I am using a stock `httpd:2.4` remote image, I will 
use that as the base image for docker-compose. 

A few notes:

* It says we should use the docker image from the first part
of this question. There are a few ways to do this:
  * Upload the file to a docker registry and point to it in the compose file.
  * Build the image locally and refer to the system's local docker registry.
  * Use the build functionality of docker-compose to build the image in the docker-compose context.

I'm using the last option.

* There are a few ways to keep the `index.html` file system. 
  * Mount a directory (or file) to a location inside the container. Typically, you mark this read-only (so your container app can not change the file). Also, you'll have to ensure the docker process has access to the directory. 
  * Compose Watch will allow updates to running Compose services but is typically used in the development workflow.

For this case, I'll mount a local directory `webroot` to `/usr/local/apache2/htdocs` inside the container.

I will also need to have the local directory have read, write, access permissions for both user and group.

"`shell
<<part2/setup-local-webroot>>=
mkdir webroot
chmod 775 webroot
@
```

"`yaml
<<part2/docker-compose.yml>>=
---
services:
  web:
    build:
      context: . 
      dockerfile: apache.dockerfile
    ports:
      - "8888:80"
    volumes:
      - ./webroot:/usr/local/apache2/htdocs:ro
@
```
# Infrastructure as Code (Part 3)

Write infrastructure-as-code to complete the following tasks. Our preference 
would be Terraform or AWS CLI, but if either of those is too much outside 
of your areas of expertise, other options are acceptable:

1. Create an AWS AMI - choose whatever base AMI you prefer
2. Updates all packages on the base AMI to the most current versions
3. Install Docker (if not already installed) on the AMI
4. In the default VPC, create a Security Group that allows SSH access from anywhere
5. In the default, VPC creates a new EC2 keypair
6. In the default VPC, create an EC2 instance using the security group and keypair from the previous steps

## Solution

I will be doing this in terraform, with the following assumptions:

* Since there is no application, and we are creating a basic EC2 image
that will be updated, have SSH installed, and accept connections. 

So, the steps will need to be:

* Create the base AMI. 
  * We have a few things that can be done here. 
  * Use Packer (or another tool) to create a custom AMI image; our terraform can use that base image.
  * Use User Data on a predefined AMI to update and configure the system as needed.

* Add docker to the AMI that we'll be using. 
  * This can be done again with a custom or prebuilt image.

I will use the Amazon Linux 2 image as the base image.

There will be a need for User Data Script to update the system and install docker.

1. Update the packages.
2. Install Docker (using Amazon Linux Extras).
3. Configure the Docker daemon to start on boot.
4. Add the ec2-user to the docker group so you can execute Docker commands without using sudo.

"`shell
#!/bin/sh
# update the packages
sudo yum update -y

# install docker using Linux Extras
sudo amazon-linux-extras install docker -y

# Configure the Docker daemon to start on boot
sudo service docker start

# Add the ec2-user to the docker group so you can execute Docker commands without using sudo.
sudo usermod -aG docker ec2-user
```

## Terraform

A few notes here. We'll be using the default VPC, and the default subnet.

First, set up the provider.

"`hcl
<<user-data>>=
user_data = <<-EOF
#!/bin/bash
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -aG docker ec2-user
EOF
@
```

Let's get the provider ready.

"`hcl
<<part3/provider.tf>>=
provider "aws" {
  region = "us-east-1" # Change this to your desired region
}
@
```

We'll need a data source to get the default VPC and, for later, the Amazon Linux 2 AMI.

"`hcl
<<part3/datasource.tf>>=
# Data source for default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source for Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["amazon"] # Use official AWS AMIs
}
@
```

Next, we'll create the security group.

"`hcl
<<part3/sg.tf>>=
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id
  revoke_rules_on_delete = true

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
@
```

__In an actual situation, I would not allow ssh from anywhere, but for this example, I will.__

Now, we'll create a keypair and store the private key in a file on the local machine.

I'll create a 4096 bit RSA keypair but use a PEM file.

"`hcl
<<part3/keypair.tf>>=
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "my-ec2-keypair"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "local_file" "ssh_key" {
  filename = "ec2-keypair.pem"
  content = tls_private_key.ec2_key.private_key_pem
  file_permission = "0400"
}
@
```

Now, we'll create the EC2 instance.

"`hcl
<<part3/ec2.tf>>=
resource "aws_instance" "ec2_instance" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.allow_ssh.name]

  <<user-data>>

  tags = {
    Name = "Docker-EC2-Instance"
    CreatedBy = "Terraform"
    Module = "SR Part 3"
    Version = "42"
  }

}
@
```

Now, we'll output some helpful information.

"`hcl
<<part3/outputs.tf>>=
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
@
```

# Written (Part 4)

1. How would you get the Docker image from part 1 onto the AMI?

There are several ways. One could create the Docker file image in the
User Data Script. Write the context to a location, build it, and start.

"`shell
# create a dockerfile and run it
cat <<DOCKERFILE > /tmp/Dockerfile
<<part1/docker.dockerfile>>
DOCKERFILE
cd /tmp
docker build -t mydocker:ipconfigme -f Dockerfile . 
docker -t run mydocker:ipconfigme
@
```

You could also use a CI solution to build the docker container (GitHub 
Actions, CircleCI, Travis CI, Jenkins) and upload the container to a
docker registry (Amazon ECR, DockerHub, Github, etc.). Then, you would
tell the docker image to run that image. Let's assume you 
upload it to Docker Hub, then you would issue a command like:

`docker run -t docker.io/mydocker:ipconfigme` to run it. 

__I would use -d here, but this container is meant to run once and stop.__

The advantage here is during the CI process, you can perform linting, 
testing, etc., to make sure the image is set correctly before uploading
it and put it into use.

2. How would you ensure the Docker container is started on boot and all subsequent reboots of the EC2 instance?

First, you ensure that docker is set up to start when the system is set up. 
This is typically handled by the system init process (old days: initv, 
current days systemd). Since most packages have systemd scripts included when you install docker, something like `systemctl enable docker` will
ensure the docker is started when the system is. 

Ensuring the docker container starts requires adding `--restart` to the docker run command, i.e., `docker run --restart=always -d -t mydocker:ipconfigme`. However, the docker image for part one runs a command and quits. Using `-d' for daemon mode and`--restart=always` for a container that runs a command and quits will cause a race condition where the container continuously restarts.

3. How would you keep the above AMI updated with future package/security updates?

Since the system updates each time it starts, and if you have an automated way to get the docker container started, one could just terminate the EC2  image and restart it. (This could be done within an AutoScaling group to bring the new systems up and, once working, bring down the old system).

In a situation like this, I would use a custom AMI image added
to a private AMI image repository. Then, I could periodically build a new
image (using something like Packer), test the image to ensure the 
application is correct, scan for security issues, and upload the 
newly backed AMI. Once again, within an AutoScaling group, I could start the new system, make sure it is up, and then kill the old system. This newly minted AMI would also have the latest docker container image installed and tested.

If that is not possible to do, you can run the OS commands to update
the system.

* `dnf update -y` for RHEL based system.
* `yun update -y` for Amazon Linux 2.
* `apt-get update && apt-get upgrade -y` for Debian/Ubuntu systems.
* `zypper -n up` for SuSE/OpenSUSE system. 

Most distributions have some scripts (yum-cron) that will allow 
automagically updating their systems.  

Install SSM on the system (I used Amazon Linux 2, which is easy to integrate with SSM).

* Add the following to the user data script.
"`shell
sudo yum install amazon-ssm-agent -y
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
```
* Set up patching baselines in AWS System Manager.
* Create maintenance windows.

One could also configure Ansible, Puppet, or Chef to run to
run on the system periodically. This would allow you to 
update packages and do additional activities after the updates
(restart docker, restart a possible web server proxying back 
to the docker image, etc.).

4. Assuming an EC2 instance exists with the above AMI running the Docker container described in the first step, how would you ensure the host EC2 instance is up to date?

Using the datasource above:
"`hcl
<<part3/datasource.tf>
```

The easiest way to redeploy the AMI (or if using the suggestions
a new current custom AMI, and deploy that). 

Incorporating regular redeployments, testing, and using SSM to maintain patching between deployments will give you an up-to-date system.

5. Assuming an EC2 instance exists with the above AMI running the Docker container described in the first step, how would you go about ensuring the Docker container is up.

Well, I have to make a change to the dockerfile.

```dockerfile
<<part1/docker.dockerfile>>=
FROM alpine:3.18
RUN apk update && apk upgrade && rm -rf /var/cache/apk/*
RUN apk add --no-cache curl
ENTRYPOINT ["/bin/sh", "-c", "curl -s https://ifconfig.me"]
@
```

While one COULD run `alpine:latest` to make sure you are at the 
the latest version of Alpine, I have found that version jumps in 
distros (not just Alpine) can cause breaks, so I would rather
stay up to date with a specific version, and only update 
the distro version after testing.

In reality, I should have put this on the original docker file
but did not.

To keep the docker image up-to-date, my first way would be to 
use the procedure I describe above. 
* Have a CI process that builds the container, tests it, and uploads it to a Docker Registry.
  * Then redeploy the custom AMI OR
  * Using something like Puppet, Ansible, or Chef (or even cron) to periodically pull down the later version of the docker image `docker pull ...` and then restart the docker image `docker stop ... && docker start ...`

Ansible, Chef, and Puppet can also be used here. A process could be 
set up to check for a new version of the docker file or docker image in 
a registry. If a new version is available, predefined steps could be taken to get the new image on the system (`docker pull,` `docker build,` etc.) and restart the docker image. 

Moving the docker image into `docker-compose` has some advantages if 
You can use the `restart --build` option for docker-compose.

