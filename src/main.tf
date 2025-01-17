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

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "sg01" {
  name        = "web_sg"
  description = " Trafego SSH e HTTP"

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
}

resource "aws_instance" "server01" {
  ami ="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  user_data = <<-EOF
              #!/bin/bash

              sudo yum update -y
              sudo yum install -y docker
              sudo systemctl start docker
              sudo systemctl enable docker

              cat /home/ec2-user/app.py

              # arquivo da aplicacao

              from flask import Flask

              app = Flask(__name__)

              @app.route('/')
              def hello():
                  return "Hello, DevOps!"

              if __name__ == '__main__':
                  app.run(host='0.0.0.0', port=80)

              # arquivo requiremnets.txt
              
              cat /home/ec2-user/requirements.txt/
              Flask==2.3.2

              # arquivo Dockerfile

              cat /home/ec2-user/Dockerfile

              # imagem base
              FROM python:3.9-slim

              # o diretório de trabalho no container
              WORKDIR /app

              # Copia os arquivos necessários para o container
              COPY app.py requirements.txt ./

              # Instalacao das dependências
              RUN pip install --no-cache-dir -r requirements.txt

              # Expõe a porta 80
              EXPOSE 80

              # inicia a aplicação
              CMD ["python", "app.py"]

              sudo docker build -t hello-devops /home/ec2-user
              sudo docker run -d -p 80:80 hello-devops

              EOF

  vpc_security_group_ids = [aws_security_group.sg01.id]
  subnet_id = module.vpc.public_subnets[0]
  
}

resource "aws_instance" "server02" {
  ami ="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  user_data = <<-EOF
              #!/bin/bash

              sudo yum update -y
              sudo yum install -y docker
              sudo systemctl start docker
              sudo systemctl enable docker

              cat /home/ec2-user/app.py

              # arquivo da aplicacao

              from flask import Flask

              app = Flask(__name__)

              @app.route('/')
              def hello():
                  return "Hello, DevOps!"

              if __name__ == '__main__':
                  app.run(host='0.0.0.0', port=80)

              # arquivo requiremnets.txt
              
              cat /home/ec2-user/requirements.txt/
              Flask==2.3.2

              # arquivo Dockerfile

              cat /home/ec2-user/Dockerfile

              # imagem base
              FROM python:3.9-slim

              # o diretório de trabalho no container
              WORKDIR /app

              # Copia os arquivos necessários para o container
              COPY app.py requirements.txt ./

              # Instalacao das dependências
              RUN pip install --no-cache-dir -r requirements.txt

              # Expõe a porta 80
              EXPOSE 80

              # inicia a aplicação
              CMD ["python", "app.py"]

              sudo docker build -t hello-devops /home/ec2-user
              sudo docker run -d -p 80:80 hello-devops

              EOF

  vpc_security_group_ids = [aws_security_group.sg01.id]
  subnet_id = module.vpc.public_subnets[1]
  
}

resource "aws_lb" "lb01" {
  name = "lb01"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.sg01.id]
  subnets = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]
}

resource "aws_lb_target_group" "tg01" {
  name = "tg01"
  port = 80
  protocol = "HTTP"
  vpc_id = module.vpc.vpc_id
  health_check {
  path = "/"
  port = "traffic-port"
 }
}

resource "aws_lb_target_group_attachment" "tga01"{
  target_group_arn = aws_lb_target_group.tg01.arn
  target_id = aws_instance.server01.id
  port = 80
}

resource "aws_lb_target_group_attachment" "tga02" {
  target_group_arn = aws_lb_target_group.tg01.arn
  target_id = aws_instance.server02.id
  port = 80
}

resource "aws_lb_listener" "lbl01" {
  load_balancer_arn = aws_lb.lb01.arn
  port = 80
  protocol = "HTTP"
  default_action {
  target_group_arn = aws_lb_target_group.tg01.arn
  type = "forward"
 }
}