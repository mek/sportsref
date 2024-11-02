Note to readers:

When I have assignments like this I like to use [Literate Programming](http://www.literateprogramming.com/) tools to show my code and my thought process. I have written my own literate programming tool [dac](bin/dac) **Documentation As Code** based on [noweb](https://www.cs.tufts.edu/~nr/noweb/). 

I use a pre-commit hook to make sure dac is run before committing. This ensures that I have created the files that I need, and I have the options of running tests and they pass before I commit code.

```
<<.git/hooks/pre-commit>>=
#!/bin/bash

# Change to the repository's root directory
cd "$(git rev-parse --show-cdup)"

# Run make clean all
make clean all

# Exit with a non-zero status code if the command fails
if [ $? -ne 0 ]; then
  echo "Error: make clean all failed"
  exit 1
fi
@
```

Thanks, /mek

---

# Docker (Part 1)

1. Create a Dockerfile that produces a Docker image that, when run as a container, outputs the external IP of the container/host and then exits

I want to say that the wording is a bit confusing, but I'll assume that it means the external IP of the host by making a curl connection to a system that reports that external IP address. On my local machine that would be the external IP address on my router, which I'll obtain it by making a curl request to `https://ifconfig.me.`


```Dockerfile
<<part1/docker.dockerfile>>=
FROM alpine:3.18
RUN apk add --no-cache curl
ENTRYPOINT ["/bin/sh", "-c", "curl -s https://ifconfig.me"]
@
```

`ip -4 -o address | sed -ne 's/.*eth.*inet *\(.*\)\/.*brd.*/\1/p'` will get 
your container IP address. 

```shell
<<run-docker>>=
dac -t -R part1/docker.dockerfile sportsref.md | \
docker build -t docker:srpart1 -f - .
docker run -p 8888:80 docker:srpart1
@
```
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

```Dockerfile
<<part2/apache.dockerfile>>=
FROM httpd:2.4
ENTRYPOINT ["/usr/local/apache2/bin/httpd", "-D", "FOREGROUND"]
@
```

Build and run the Docker container with the following commands:

```shell
<<run-apache-docker>>=
dac -t -R part2/apache.dockerfile sportsref.md | \
docker build -t docker:srpart2 -f - .
docker run -p 8888:80 docker:srpart2 
@
```

```Dockerfile
<<part2/apache8888.dockerfile>>=
FROM httpd:2.4
ENTRYPOINT ["/usr/local/apache2/bin/apachectl", "-D", "FOREGROUND", "-D", "HTTP_PORT=8888"]
@
```

Build and run the Docker container with the following commands:

```shell
<<run-apache8888-docker>>=
dac -t -R part2/apache8888.dockerfile sportsref.md | \
docker build -t docker8888:srpart2 -f - .
docker run -p 8888:8888 docker8888:srpart2 
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

```shell
<<part2/setup-local-webroot>>=
mkdir webroot
chmod 775 webroot
echo "We democratize data, so our users enjoy, understand, and share the sports they love." > webroot/index.html
@
```

```yaml
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

```shell
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

```hcl
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

```hcl
<<part3/provider.tf>>=
provider "aws" {
  region = "us-east-1" # Change this to your desired region
}
@
```

We'll need a data source to get the default VPC and, for later, the Amazon Linux 2 AMI.

```hcl
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

```hcl
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

```hcl
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

```hcl
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

```hcl
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

```shell
<<user-data-docker-file>>=
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
```shell
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
```hcl
<<datasource>>=
<<part3/datasource.tf>>
@
```

The easiest way to redeploy the AMI (or if using the suggestions
a new current custom AMI, and deploy that). 

Incorporating regular redeployments, testing, and using SSM to maintain patching between deployments will give you an up-to-date system.

5. Assuming an EC2 instance exists with the above AMI running the Docker container described in the first step, how would you go about ensuring the Docker container is up.

Well, I have to make a change to the dockerfile.

```dockerfile
<<part3/docker.dockerfile>>=
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

---

Testing:

; make run-part1
```
#0 building with "rancher-desktop" instance using docker driver

#1 [internal] load build definition from docker.dockerfile
#1 transferring dockerfile: 313B 0.0s done
#1 DONE 0.0s

#2 [internal] load metadata for docker.io/library/alpine:3.18
#2 DONE 0.0s

#3 [internal] load .dockerignore
#3 transferring context: 2B done
#3 DONE 0.0s

#4 [stage-1 1/3] FROM docker.io/library/alpine:3.18
#4 DONE 0.0s

#5 [stage-1 2/3] RUN apk update && apk upgrade && rm -rf /var/cache/apk/*
#5 CACHED

#6 [stage-1 3/3] RUN apk add --no-cache curl
#6 CACHED

#7 exporting to image
#7 exporting layers done
#7 writing image sha256:05c63c0f1f26edc954715aa02c62cfb2bf0ea93c24b7edb176783433ad4e6e96 done
#7 naming to docker.io/library/docker:srpart1 done
#7 DONE 0.0s
75.118.59.7
```
; make run-part2a
```
% make run-part2a
#0 building with "rancher-desktop" instance using docker driver

#1 [internal] load build definition from apache.dockerfile
#1 transferring dockerfile: 123B done
#1 DONE 0.0s

#2 [internal] load metadata for docker.io/library/httpd:2.4
#2 DONE 0.0s

#3 [internal] load .dockerignore
#3 transferring context: 2B done
#3 DONE 0.0s

#4 [1/1] FROM docker.io/library/httpd:2.4
#4 CACHED

#5 exporting to image
#5 exporting layers done
#5 writing image sha256:c61344c777bb9929480f62fbb3008145b7c14d69e51876112e67761c73b5a29f done
#5 naming to docker.io/library/docker:srpart2a done
#5 DONE 0.0s
#0 building with "rancher-desktop" instance using docker driver

#1 [internal] load build definition from apache8888.dockerfile
#1 transferring dockerfile: 155B done
#1 DONE 0.0s

#2 [internal] load metadata for docker.io/library/httpd:2.4
#2 DONE 0.0s

#3 [internal] load .dockerignore
#3 transferring context: 2B done
#3 DONE 0.0s

#4 [1/1] FROM docker.io/library/httpd:2.4
#4 CACHED

#5 exporting to image
#5 exporting layers done
#5 writing image sha256:08689bfa4a3b407e93e900d4033c506e6d9d288d82757a962dc1ab5be3765074 done
#5 naming to docker.io/library/docker:srpart2b done
#5 DONE 0.0s
#0 building with "rancher-desktop" instance using docker driver

#1 [web internal] load build definition from apache.dockerfile
#1 transferring dockerfile: 123B done
#1 DONE 0.0s

#2 [web internal] load metadata for docker.io/library/httpd:2.4
#2 DONE 0.0s

#3 [web internal] load .dockerignore
#3 transferring context: 2B done
#3 DONE 0.0s

#4 [web 1/1] FROM docker.io/library/httpd:2.4
#4 CACHED

#5 [web] exporting to image
#5 exporting layers done
#5 writing image sha256:1e337719117aafe48df416784bed487a6c4665c06d30dcf508dc5610f6ac99de done
#5 naming to docker.io/library/part2-web done
#5 DONE 0.0s

#6 [web] resolving provenance for metadata file
#6 DONE 0.0s
AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 172.17.0.2. Set the 'ServerName' directive globally to suppress this message
AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 172.17.0.2. Set the 'ServerName' directive globally to suppress this message
[Tue Oct 22 14:13:54.018646 2024] [mpm_event:notice] [pid 1:tid 1] AH00489: Apache/2.4.62 (Unix) configured -- resuming normal operations
[Tue Oct 22 14:13:54.023510 2024] [core:notice] [pid 1:tid 1] AH00094: Command line: '/usr/local/apache2/bin/httpd -D FOREGROUND'
172.17.0.1 - - [22/Oct/2024:14:15:31 +0000] "GET / HTTP/1.1" 200 45

Checking: 

curl  http://localhost:8888[?2004l
<html><body><h1>It works!</h1></body></html>
```

; make run-part2b
```
#0 building with "rancher-desktop" instance using docker driver

#1 [internal] load build definition from apache.dockerfile
#1 transferring dockerfile: 123B done
#1 DONE 0.0s

#2 [internal] load metadata for docker.io/library/httpd:2.4
#2 DONE 0.0s

#3 [internal] load .dockerignore
#3 transferring context: 2B done
#3 DONE 0.0s

#4 [1/1] FROM docker.io/library/httpd:2.4
#4 CACHED

#5 exporting to image
#5 exporting layers done
#5 writing image sha256:c61344c777bb9929480f62fbb3008145b7c14d69e51876112e67761c73b5a29f done
#5 naming to docker.io/library/docker:srpart2a done
#5 DONE 0.0s
#0 building with "rancher-desktop" instance using docker driver

#1 [internal] load build definition from apache8888.dockerfile
#1 transferring dockerfile: 155B done
#1 DONE 0.0s

#2 [internal] load metadata for docker.io/library/httpd:2.4
#2 DONE 0.0s

#3 [internal] load .dockerignore
#3 transferring context: 2B done
#3 DONE 0.0s

#4 [1/1] FROM docker.io/library/httpd:2.4
#4 CACHED

#5 exporting to image
#5 exporting layers done
#5 writing image sha256:08689bfa4a3b407e93e900d4033c506e6d9d288d82757a962dc1ab5be3765074 done
#5 naming to docker.io/library/docker:srpart2b done
#5 DONE 0.0s
#0 building with "rancher-desktop" instance using docker driver

#1 [web internal] load build definition from apache.dockerfile
#1 transferring dockerfile: 123B done
#1 DONE 0.0s

#2 [web internal] load metadata for docker.io/library/httpd:2.4
#2 DONE 0.0s

#3 [web internal] load .dockerignore
#3 transferring context: 2B done
#3 DONE 0.0s

#4 [web 1/1] FROM docker.io/library/httpd:2.4
#4 CACHED

#5 [web] exporting to image
#5 exporting layers done
#5 writing image sha256:1e337719117aafe48df416784bed487a6c4665c06d30dcf508dc5610f6ac99de done
#5 naming to docker.io/library/part2-web done
#5 DONE 0.0s

#6 [web] resolving provenance for metadata file
#6 DONE 0.0s
[+] Running 1/0
 ✔ Container part2-web-1  Created                                                         0.0s
Attaching to web-1
web-1  | AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 172.19.0.2. Set the 'ServerName' directive globally to suppress this message
web-1  | AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 172.19.0.2. Set the 'ServerName' directive globally to suppress this message
web-1  | [Tue Oct 22 14:17:45.225986 2024] [mpm_event:notice] [pid 1:tid 1] AH00489: Apache/2.4.62 (Unix) configured -- resuming normal operations
web-1  | [Tue Oct 22 14:17:45.228425 2024] [core:notice] [pid 1:tid 1] AH00094: Command line: '/usr/local/apache2/bin/httpd -D FOREGROUND'

curl http://localhost:8888
We democratize data, so our users enjoy, understand, and share the sports they love.
```

; make apply-part3
```
Not showing info all info:

tls_private_key.ec2_key: Creating...
aws_security_group.allow_ssh: Creating...
tls_private_key.ec2_key: Creation complete after 1s [id=cda12d5401816ce4b32c44937dcb77f46c0575d8]
aws_key_pair.ec2_key_pair: Creating...
local_file.ssh_key: Creating...
local_file.ssh_key: Creation complete after 0s [id=3f8b262b6cc8feab8ba33b1ef9a5f56ced0442cf]
aws_key_pair.ec2_key_pair: Creation complete after 1s [id=my-ec2-keypair]
aws_security_group.allow_ssh: Creation complete after 2s [id=sg-03ce8933f81dc633c]
aws_instance.ec2_instance: Creating...
aws_instance.ec2_instance: Still creating... [10s elapsed]
aws_instance.ec2_instance: Creation complete after 14s [id=i-05753d7d471a07f30]

% ssh -i part3/ec2-keypair.pem ec2-user@54.196.156.188
The authenticity of host '54.196.156.188 (54.196.156.188)' can't be established.
ED25519 key fingerprint is SHA256:hlGZwKeE6T7Dh57q7BMiRqRnmjg8/bWAfiKa9wPX3nA.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '54.196.156.188' (ED25519) to the list of known hosts.
   ,     #_
   ~\_  ####_        Amazon Linux 2
  ~~  \_#####\
  ~~     \###|       AL2 End of Life is 2025-06-30.
  ~~       \#/ ___
   ~~       V~' '->
    ~~~         /    A newer version of Amazon Linux is available!
      ~~._.   _/
         _/ _/       Amazon Linux 2023, GA and supported until 2028-03-15.
       _/m/'           https://aws.amazon.com/linux/amazon-linux-2023/

[ec2-user@ip-172-31-15-18 ~]$ docker version
Client:
 Version:           25.0.5
 API version:       1.44
 Go version:        go1.22.5
 Git commit:        5dc9bcc
 Built:             Thu Aug 22 17:25:26 2024
 OS/Arch:           linux/amd64
 Context:           default

Server:
 Engine:
  Version:          25.0.6
  API version:      1.44 (minimum version 1.24)
  Go version:       go1.22.5
  Git commit:       b08a51f
  Built:            Thu Aug 22 17:26:01 2024
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.7.22
  GitCommit:        7f7fdf5fed64eb6a7caf99b3e12efcf9d60e311c
 runc:
  Version:          1.1.14
  GitCommit:        2c9f5602f0ba3d9da1c2596322dfc4e156844890
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```

q.e.d
