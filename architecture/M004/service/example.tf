// 定义本地变量
locals {
  // 全局变量，用于构建AWS资源的ARN
  global = "aws"
  // AWS区域
  region = "ap-southeast-1"
  // 主体服务的Lambda函数的压缩包，案例不提供，有需要可以自己编写。
  listenerfunction = "http_listener.zip"
}

// 定义AWS提供者
provider "aws" {
  // 使用本地变量中定义的区域
  region = local.region
}

// 获取当前AWS账户的信息
data "aws_caller_identity" "current" {}

// 创建SQS队列
resource "aws_sqs_queue" "my_queue" {
  // 队列名称
  name = "my-queue"
}

// 创建Lambda函数
resource "aws_lambda_function" "http_listener" {
  // 函数名称
  function_name = "http_listener"
  // 执行角色
  role = aws_iam_role.lambda_exec.arn
  // 处理器
  handler = "index.handler"
  // 运行时环境
  runtime = "nodejs18.x"
  // 函数文件名
  filename = local.listenerfunction
  // 环境变量
  environment {
    variables = {
      // SQS队列的URL
      SQS_QUEUE_URL = aws_sqs_queue.my_queue.url
    }
  }
}

// 创建IAM角色
resource "aws_iam_role" "lambda_exec" {
  // 角色名称
  name = "lambda_exec_role"

  // 角色的信任策略
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

// 创建IAM角色策略
resource "aws_iam_role_policy" "lambda_exec_policy" {
  // 策略名称
  name = "lambda_exec_policy"
  // 角色ID
  role = aws_iam_role.lambda_exec.id

  // 策略内容
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "logs:CreateLogGroup",
      "Resource": "${format("arn:%s:logs:%s:%s:*", local.global, local.region, data.aws_caller_identity.current.account_id)}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "${format("arn:%s:logs:%s:%s:log-group:/aws/lambda/%s:*", local.global, local.region, data.aws_caller_identity.current.account_id, aws_lambda_function.http_listener.function_name)}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "${aws_sqs_queue.my_queue.arn}"
    }
  ]
}
EOF
}

// 创建API Gateway
resource "aws_apigatewayv2_api" "my_api" {
  // API名称
  name = "my-api"
  // 协议类型
  protocol_type = "HTTP"
}

// 创建Lambda权限
resource "aws_lambda_permission" "apigw" {
  // 声明ID
  statement_id = "AllowExecutionFromAPIGateway"
  // 动作
  action = "lambda:InvokeFunction"
  // 函数名称
  function_name = aws_lambda_function.http_listener.function_name
  // 主体
  principal = "apigateway.amazonaws.com"

  // 来源ARN
  source_arn = "${aws_apigatewayv2_api.my_api.execution_arn}/*/*"
}

// 创建API Gateway的默认阶段
resource "aws_apigatewayv2_stage" "default" {
  // API ID
  api_id = aws_apigatewayv2_api.my_api.id
  // 阶段名称
  name = "$default"
  // 自动部署
  auto_deploy = true
}

// 创建API Gateway的集成
resource "aws_apigatewayv2_integration" "my_integration" {
  // API ID
  api_id = aws_apigatewayv2_api.my_api.id
  // 集成类型
  integration_type = "AWS_PROXY"

  // 连接类型
  connection_type = "INTERNET"
  // 描述
  description = "Lambda integration"
  // 集成方法
  integration_method = "POST"
  // 集成URI
  integration_uri = aws_lambda_function.http_listener.invoke_arn
  // 载荷格式版本
  payload_format_version = "2.0"
}

// 创建API Gateway的路由
resource "aws_apigatewayv2_route" "my_route" {
  // API ID
  api_id = aws_apigatewayv2_api.my_api.id
  // 路由键
  route_key = "ANY /call"

  // 目标
  target = "integrations/${aws_apigatewayv2_integration.my_integration.id}"
}

// 输出API端点
output "api_endpoint" {
  // 描述
  description = "The endpoint of the API Gateway"
  // 值
  value = "${aws_apigatewayv2_api.my_api.api_endpoint}/call"
}

// 创建EC2执行角色
resource "aws_iam_role" "ec2_exec" {
  // 角色名称
  name = "ec2_exec_role"

  // 角色的信任策略
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

// 创建EC2执行策略
resource "aws_iam_role_policy" "ec2_exec_policy" {
  // 策略名称
  name = "ec2_exec_policy"
  // 角色ID
  role = aws_iam_role.ec2_exec.id

  // 策略内容
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "${aws_sqs_queue.my_queue.arn}"
    }
  ]
}
EOF
}

// 创建EC2实例配置文件
resource "aws_iam_instance_profile" "ec2_exec_profile" {
  // 配置文件名称
  name = "ec2_exec_profile"
  // 角色名称
  role = aws_iam_role.ec2_exec.name
}

// 创建EC2实例请求
resource "aws_spot_instance_request" "sqs_processor" {
  // 镜像ID
  ami = "ami-0fa377108253bf620"
  // 实例类型
  instance_type = "t2.micro"
  // 竞价价格
  spot_price = "0.01"
  // IAM实例配置文件
  iam_instance_profile = aws_iam_instance_profile.ec2_exec_profile.name

  // 用户数据，用于在实例启动时运行脚本，这里只是举个例子，服务代码需要处理鉴权、日志等事项。
  user_data = <<-EOF
              #!/bin/bash
              // 安装Node.js
              curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
              sudo apt-get install -y nodejs
              // 从S3下载服务内容
              aws s3 cp s3://my-bucket/sqs_processor.zip /home/ubuntu/
              // 解压Lambda函数
              unzip /home/ubuntu/sqs_processor.zip -d /home/ubuntu/
              // 将Lambda函数添加到rc.local，使其在启动时运行
              echo "node /home/ubuntu/index.js" >> /etc/rc.local
              EOF
}