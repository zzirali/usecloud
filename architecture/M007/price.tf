// 定义本地变量
locals {
  // 全局变量，用于构建AWS资源的ARN
  global = "aws"
  // AWS区域
  region = "ap-southeast-1"
  // 处理Lambda函数的压缩包，里面只有删除EC2实例的操作，可以自己编写预算通知的处理逻辑代码
  functionpath = "price_exec.zip"
  // 实例ID，用于Lambda函数操作指定的EC2实例，这里假设要做指定EC2实例的处理，实际应用中应该调用API动态分析来确定。
  instance_id = "i-0261f9f9091ca1300"
}

// 定义AWS提供者，指定操作的区域
provider "aws" {
  // 使用本地变量中定义的区域
  region = local.region
}

// 获取当前调用者的身份信息，用于资源的ARN构建
data "aws_caller_identity" "current" {}

// 创建SNS主题，用于发送和接收通知
resource "aws_sns_topic" "price_notify" {
  name = "price_notify"
}

// 为SNS主题创建访问策略，允许AWS Budgets服务向其发布消息
resource "aws_sns_topic_policy" "price_notify_policy" {
  arn = aws_sns_topic.price_notify.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSBudgets-notification-1"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.price_notify.arn
      }
    ]
  })
}

// 创建IAM角色，Lambda函数将使用此角色执行操作
resource "aws_iam_role" "lambda_execution_role" {
  name = "price_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

// 创建Lambda函数，用于执行价格通知相关的逻辑
resource "aws_lambda_function" "price_lambda" {
  filename      = local.functionpath
  function_name = "price_exec"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  environment {
    variables = {
      INSTANCE_ID = local.instance_id
    }
  }
}

// 创建IAM策略，授予Lambda函数访问日志和终止EC2实例的权限
resource "aws_iam_policy" "lambda_policy" {
  name        = "price_lambda_policy"
  description = "可以删除当前区域的EC2所有实例和写入日志"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : "logs:CreateLogGroup",
        "Resource" : "${format("arn:%s:logs:%s:%s:*", local.global, local.region, data.aws_caller_identity.current.account_id)}"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : [
          "${format("arn:%s:logs:%s:%s:log-group:/aws/lambda/%s:*", local.global, local.region, data.aws_caller_identity.current.account_id, aws_lambda_function.price_lambda.function_name)}"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : "ec2:TerminateInstances",
        "Resource" : "${format("arn:%s:ec2:%s:%s:*", local.global, local.region, data.aws_caller_identity.current.account_id)}"
      }
    ]
  })
}

// 将IAM策略附加到Lambda执行角色上，使其生效
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

// 创建Lambda权限，允许SNS主题触发Lambda函数
resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.price_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.price_notify.arn
}

// 创建SNS主题订阅，将Lambda函数订阅到SNS主题，以便接收并处理通知
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.price_notify.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.price_lambda.arn
}