# ECS Resource
# This assumes you already have ECR setup and the image placed in ECR.
resource "aws_ecs_cluster" "discord" {
  name = var.project_id
}

resource "aws_ecr_repository" "ecr" {
  name                 = var.project_id
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Tier = "Public"
  }
}

data "aws_kms_key" "ebs" {
  key_id = "alias/aws/ebs"
}


# EC2 Launch Template with Nvidia drivers and ECS Drivers
# Make sure your aws config is setup with the region you want to deploy!
data "aws_ssm_parameter" "ecs_gpu_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id"
}

resource "aws_launch_template" "discord_diffusion" {
  name = var.project_id

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 40
      volume_type = "gp3"
      encrypted   = true
      kms_key_id  = data.aws_kms_key.ebs.arn
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_discord.arn
  }

  image_id                             = data.aws_ssm_parameter.ecs_gpu_ami.value
  update_default_version               = true
  instance_initiated_shutdown_behavior = "terminate"

  # # Uncomment this if you are wanting to run spot instances for your GPU instances. Cost savings!
  #   instance_market_options {
  #     market_type = "spot"
  #   }

  instance_type = "g4dn.xlarge"

  # If you want to ssh/login to your instances, reference your key pair here.
  # key_name = "YOUR KEY PAIR HERE"
  vpc_security_group_ids = [aws_security_group.ecs_discord.id]

  user_data = base64encode(
    <<EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${aws_ecs_cluster.discord.id}
    ECS_ENABLE_GPU_SUPPORT=true
    EOF
    EOT
  )

  depends_on = [
    aws_ecs_cluster.discord,
    aws_security_group.ecs_discord
  ]

  tags = {
    Name = "${var.project_id}"
  }

}

resource "aws_security_group" "ecs_discord" {
  name        = "ECS-Discord-${var.project_id}"
  description = "Allow TLS inbound traffic"
  vpc_id      = var.vpc_id

  # # Be descriptive on the cidr_blocks of your ip address if you want to uncomment.
  #   ingress {
  #     description      = "SSH"
  #     from_port        = 22
  #     to_port          = 22
  #     protocol         = "tcp"
  #     cidr_blocks      = ["0.0.0.0/0"]
  #   }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Role for ECS
resource "aws_iam_role" "ecs_discord" {
  name = "DiscordECS-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ecs_discord" {
  name = "ECS-Discord-${var.project_id}"
  role = aws_iam_role.ecs_discord.name
}

resource "aws_iam_policy" "AWSLambdaSQSQueueExecutionRole" {
  name        = "AWSLambdaSQSQueueExecutionRole-${var.project_id}"
  path        = "/"
  description = "IAM policy for containers to query SQS queue"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",

        ],
        "Resource" : "arn:aws:sqs:${var.region}:${var.account_id}:${var.project_id}.fifo"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "AmazonEC2ContainerServiceforEC2Role" {
  name        = "AmazonEC2ContainerServiceforEC2Role-${var.project_id}"
  path        = "/"
  description = "IAM policy EC2 Container Service Role"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecs:Poll",
                "ecs:StartTelemetrySession",
                "ecr:GetDownloadUrlForLayer",
                "ecs:UpdateContainerInstancesState",
                "ecr:BatchGetImage",
                "ecs:RegisterContainerInstance",
                "ecs:Submit*",
                "ecs:DeregisterContainerInstance",
                "ecr:BatchCheckLayerAvailability"
            ],
            "Resource": [
                "arn:aws:ecr:${var.region}:${var.account_id}:repository/${var.project_id}",
                "arn:aws:ecs:${var.region}:${var.account_id}:cluster/${var.project_id}",
                "arn:aws:ecs:${var.region}:${var.account_id}:container-instance/${var.project_id}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecs:DiscoverPollEndpoint",
                "logs:CreateLogStream",
                "ec2:DescribeTags",
                "ecs:CreateCluster",
                "ecr:GetAuthorizationToken",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AWSLambdaSQSQueueExecutionRole" {
  role       = aws_iam_role.ecs_discord.name
  policy_arn = resource.aws_iam_policy.AWSLambdaSQSQueueExecutionRole.arn
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerServiceforEC2Role" {
  role       = aws_iam_role.ecs_discord.name
  policy_arn = resource.aws_iam_policy.AmazonEC2ContainerServiceforEC2Role.arn
}

# SSM Parameters for hugging face
resource "aws_ssm_parameter" "username_hg" {
  name        = "USER_HG"
  description = "Hugging Face Username"
  type        = "String"
  value       = var.huggingface_username
}

resource "aws_ssm_parameter" "password_hg" {
  name        = "PASSWORD_HG"
  description = "Hugging Face Password"
  type        = "SecureString"
  value       = var.huggingface_password
}

# ECS Task
resource "aws_iam_role" "ecs_execution" {
  name = "ecsExecution-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_param_hg" {
  name        = "hg-${var.project_id}"
  path        = "/"
  description = "IAM policy for SSM Read user and password Hugging Face"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:Decrypt",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ],
        "Resource" : [
          "arn:aws:kms:*:${var.account_id}:alias/aws/ssm",
          "${aws_ssm_parameter.username_hg.arn}",
          "${aws_ssm_parameter.password_hg.arn}"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "AmazonECSTaskExecutionRolePolicy" {
  name        = "AmazonECSTaskExecutionRolePolicy-${var.project_id}"
  path        = "/"
  description = "IAM policy for ECS Task Execution"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability"
            ],
            "Resource": "arn:aws:ecr:${var.region}:${var.account_id}:repository/${var.project_id}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "ecr:GetAuthorizationToken",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
})
}

resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = resource.aws_iam_policy.AmazonECSTaskExecutionRolePolicy.arn
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTask-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AWSLambdaSQSQueueExecutionRole_ECS" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = resource.aws_iam_policy.AWSLambdaSQSQueueExecutionRole.arn
}

resource "aws_iam_role_policy_attachment" "ssm_param_hg" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ssm_param_hg.arn
}

### ECS Task
resource "aws_ecs_task_definition" "ecs_task" {
  # family                = "test"
  family                   = var.project_id
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = <<TASK_DEFINITION
  [
    {
        "name": "${var.project_id}",
        "image": "${aws_ecr_repository.ecr.repository_url}:latest",
        "cpu": 4096,
        "memory": 12288,
        "links": [],
        "portMappings": [],
        "essential": true,
        "entryPoint": [],
        "command": [],
        "environment": [
            {
                "name": "SQSQUEUEURL",
                "value": "${var.sqs_queue_url}"
            },
            {
                "name": "REGION",
                "value": "${var.region}"
            }
        ],
        "environmentFiles": [],
        "mountPoints": [],
        "volumesFrom": [],
        "secrets": [],
        "dnsServers": [],
        "dnsSearchDomains": [],
        "extraHosts": [],
        "dockerSecurityOptions": [],
        "dockerLabels": {},
        "ulimits": [],
        "systemControls": [],
        "resourceRequirements": [
            {
                "value": "1",
                "type": "GPU"
            }
        ]
    }
  ]
  TASK_DEFINITION

  depends_on = [
    aws_iam_role.ecs_task_role,
    aws_iam_role.ecs_execution
  ]
}

### ECS Service ###
resource "aws_ecs_service" "discord_diffusion" {
  name            = var.project_id
  cluster         = aws_ecs_cluster.discord.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  desired_count   = 0

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}