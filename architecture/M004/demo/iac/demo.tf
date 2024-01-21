// 定义一些本地变量
locals {
  global            = "aws"               // 全局变量，表示我们正在使用的云服务提供商
  region            = "ap-southeast-1"    // AWS的区域代码
  listenerfunction  = "http_listener.zip" // HTTP监听器的Lambda函数的文件名
  processorfunction = "sqs_processor.zip" // SQS处理器的Lambda函数的文件名
}

// 定义AWS提供商，并设置区域
provider "aws" {
  region = local.region
}

// 获取当前调用者的身份信息
data "aws_caller_identity" "current" {}

// 创建一个SQS队列
resource "aws_sqs_queue" "my_queue" {
  name = "my-queue"
}

// 创建一个Lambda函数，用于HTTP监听
resource "aws_lambda_function" "http_listener" {
  function_name = "http_listener"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = local.listenerfunction
  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.my_queue.url // 环境变量，指向我们的SQS队列
    }
  }
}

// 创建一个Lambda函数，用于处理SQS消息
resource "aws_lambda_function" "sqs_processor" {
  function_name = "sqs_processor"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = local.processorfunction
}

// 创建一个IAM角色，供Lambda函数使用
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

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

// 创建一个IAM策略，允许Lambda函数创建日志组，创建日志流，写入日志事件，以及操作SQS队列
resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "lambda_exec_policy"
  role = aws_iam_role.lambda_exec.id

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
        "${format("arn:%s:logs:%s:%s:log-group:/aws/lambda/%s:*", local.global, local.region, data.aws_caller_identity.current.account_id, aws_lambda_function.http_listener.function_name)}",
        "${format("arn:%s:logs:%s:%s:log-group:/aws/lambda/%s:*", local.global, local.region, data.aws_caller_identity.current.account_id, aws_lambda_function.sqs_processor.function_name)}"
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

// 创建一个Lambda事件源映射，将SQS队列与SQS处理器Lambda函数关联起来
resource "aws_lambda_event_source_mapping" "sqs_processor_mapping" {
  depends_on       = [aws_iam_role_policy.lambda_exec_policy]
  event_source_arn = aws_sqs_queue.my_queue.arn
  function_name    = aws_lambda_function.sqs_processor.arn
}

// 创建一个API Gateway
resource "aws_apigatewayv2_api" "my_api" {
  name          = "my-api"
  protocol_type = "HTTP"
}

// 创建一个Lambda权限，允许API Gateway调用我们的HTTP监听器Lambda函数
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.http_listener.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.my_api.execution_arn}/*/*"
}

// 创建一个API Gateway的默认阶段
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.my_api.id
  name        = "$default"
  auto_deploy = true
}

// 创建一个API Gateway的集成，将API Gateway与我们的HTTP监听器Lambda函数关联起来
resource "aws_apigatewayv2_integration" "my_integration" {
  api_id           = aws_apigatewayv2_api.my_api.id
  integration_type = "AWS_PROXY"

  connection_type        = "INTERNET"
  description            = "Lambda integration"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.http_listener.invoke_arn
  payload_format_version = "2.0"
}

// 创建一个API Gateway的路由，将任何请求都转发到我们的集成
resource "aws_apigatewayv2_route" "my_route" {
  api_id    = aws_apigatewayv2_api.my_api.id
  route_key = "ANY /call"

  target = "integrations/${aws_apigatewayv2_integration.my_integration.id}"
}

// 输出API Gateway的端点
output "api_endpoint" {
  description = "The endpoint of the API Gateway"
  value       = "${aws_apigatewayv2_api.my_api.api_endpoint}/call"
}