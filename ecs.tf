provider "aws" {
  region = "${var.region}"
}

terraform {
  # backend "s3" {}
  cloud {
    organization = "von-herff-gallery"
    workspaces {
      name = "vhg-infra-platform"
    }
  }
}

data "terraform_remote_state" "infrastructure" {
  backend = "remote"

  config = {
    organization = "von-herff-gallery"
    workspaces = {
      name = "vhg-infra"
    }
  }
}

resource "aws_ecs_cluster" "production_fargate_cluster" {
  name = "Production-Fargate-Cluster"
}

resource "aws_alb" "ecs_cluster_alb" {
  name = "${var.ecs_cluster_name}-ALB"
  internal = false
  security_groups = ["${aws_security_group.ecs_alb_security_group.id}"]
  # TODO: Figure out how to interate through these three public subnets instead of declaring each
  # one
  # subnets = ["${split(",", join(",", data.terraform_remote_state.infrastructure.outputs.public_subnets))}"]
  # subnets = ["${data.terraform_remote_state.infrastructure.outputs.public_subnet_1_id}, ${data.terraform_remote_state.infrastructure.outputs.public_subnet_2_id}, ${data.terraform_remote_state.infrastructure.outputs.public_subnet_3_id}"]
  
  subnet_mapping {
    subnet_id = "${data.terraform_remote_state.infrastructure.outputs.public_subnet_1_id}"
  }

  subnet_mapping {
    subnet_id = "${data.terraform_remote_state.infrastructure.outputs.public_subnet_2_id}"
  }

  subnet_mapping {
    subnet_id = "${data.terraform_remote_state.infrastructure.outputs.public_subnet_3_id}"
  }


  tags = {
    Name = "${var.ecs_cluster_name}-ALB"
  }
}

resource "aws_alb_listener" "ecs_alb_https_listener" {
  load_balancer_arn = "${aws_alb.ecs_cluster_alb.arn}"
  port = 443
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn = "${aws_acm_certificate.ecs_domain_certificate.arn}"

  default_action {
    type = "forward"
    target_group_arn = "${aws_alb_target_group.ecs_default_target_group.arn}"
  }

  depends_on = [aws_alb_target_group.ecs_default_target_group]
}

resource "aws_alb_target_group" "ecs_default_target_group" {
  name = "${var.ecs_cluster_name}-TG"
  port = 80
  protocol = "HTTP"
  vpc_id = "${data.terraform_remote_state.infrastructure.outputs.vpc_id}"

  tags = {
    Name = "${var.ecs_cluster_name}-TG"
  }
}

resource "aws_route53_record" "ecs_load_balancer_record" {
  name = "*.${var.ecs_domain_name}"
  type = "A"
  zone_id = "${data.aws_route53_zone.ecs_domain.zone_id}"

  alias {
    evaluate_target_health = false
    name = "${aws_alb.ecs_cluster_alb.dns_name}"
    zone_id = "${aws_alb.ecs_cluster_alb.zone_id}"
  }  
}

resource "aws_iam_role" "ecs_cluster_role" {
  name = "${var.ecs_cluster_name}-IAM-Role"
  assume_role_policy = jsonencode({
    Version: "2012-10-17"
    Statement: [
      {
        Effect: "Allow"
        Principal: {
          Service: ["ecs.amazonaws.com", "ec2.amazonaws.com", "application-autoscaling.amazonaws.com"]
        },
        Action: "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_cluster_policy" {
  name = "${var.ecs_cluster_name}-IAM-Policy"
  role = "${aws_iam_role.ecs_cluster_role.id}"
  policy = jsonencode({
    Version: "2012-10-17"
    Statement: [
      {
        Effect: "Allow"
        Action: [
          "ecs:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "ecr:*",
          "cloudwatch:*",
          "s3:*",
          "logs:*"
        ]
        Resource: "*"
      }
    ]
  })
}