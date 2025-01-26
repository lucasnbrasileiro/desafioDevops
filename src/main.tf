terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.83.1"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "vpc01"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
  }

resource "aws_security_group" "sg01" {

  name        = "web_sg"
  description = "Trafego SSH e HTTP"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "server01" {
  ami ="ami-04b4f1a9cf54c11d0" # Ubuntu 24.04
  instance_type = "t2.micro"
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io

              sudo systemctl start docker
              sudo systemctl enable docker

              sudo usermod -aG docker ubuntu

              sudo mkdir /app && cd /app

              # Criar arquivos da aplicação
              sudo echo 'from flask import Flask

              app = Flask(__name__)

              @app.route("/")
              def hello():
                  return "Hello, DevOps! 1"

              if __name__ == "__main__":
                  app.run(host="0.0.0.0", port=80)' > app.py

              sudo echo 'Flask==2.3.2' > requirements.txt

              sudo echo 'FROM python:3.9-slim
              WORKDIR /app
              COPY app.py requirements.txt ./
              RUN pip install --no-cache-dir -r requirements.txt
              EXPOSE 80
              CMD ["python", "app.py"]' > Dockerfile

              # Construir e executar o container
              sudo docker build -t hello-devops .
              sudo docker run -d -p 80:80 hello-devops
              EOF
      
  vpc_security_group_ids = [aws_security_group.sg01.id]
  subnet_id = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  
}

resource "aws_instance" "server02" {
  ami ="ami-04b4f1a9cf54c11d0" # Ubuntu 24.04
  instance_type = "t2.micro"
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io

              sudo systemctl start docker
              sudo systemctl enable docker

              sudo usermod -aG docker ubuntu

              sudo mkdir /app && cd /app

              # Criar arquivos da aplicação
              sudo echo 'from flask import Flask

              app = Flask(__name__)

              @app.route("/")
              def hello():
                  return "Hello, DevOps! 2"

              if __name__ == "__main__":
                  app.run(host="0.0.0.0", port=80)' > app.py

              sudo echo 'Flask==2.3.2' > requirements.txt

              sudo echo 'FROM python:3.9-slim
              WORKDIR /app
              COPY app.py requirements.txt ./
              RUN pip install --no-cache-dir -r requirements.txt
              EXPOSE 80
              CMD ["python", "app.py"]' > Dockerfile

              # Construir e executar o container
              sudo docker build -t hello-devops .
              sudo docker run -d -p 80:80 hello-devops
              EOF
      
  vpc_security_group_ids = [aws_security_group.sg01.id]
  subnet_id = module.vpc.public_subnets[1]
  associate_public_ip_address = true
  
}

resource "aws_lb_target_group" "tg01" {
  name = "tg01"
  port = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id = module.vpc.vpc_id

  health_check {
  enabled = true
  interval = 10  
  path = "/"
  port = "traffic-port"
  protocol = "HTTP"
  timeout = 5
  healthy_threshold = 2
  unhealthy_threshold = 2

 }
}

resource "aws_lb" "lb01" {
  name = "lb01"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.sg01.id]
  subnets = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]
  ip_address_type = "ipv4"
}

resource "aws_lb_listener" "lbl01" {
  load_balancer_arn = aws_lb.lb01.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg01.arn
 }
}

resource "aws_lb_target_group_attachment" "tga01"{
  target_group_arn = aws_lb_target_group.tg01.arn
  target_id = aws_instance.server01.id
}

resource "aws_lb_target_group_attachment" "tga02"{
  target_group_arn = aws_lb_target_group.tg01.arn
  target_id = aws_instance.server02.id
}
