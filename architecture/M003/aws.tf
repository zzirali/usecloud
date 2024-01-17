# 创建IAM策略，授予Lambda函数对DynamoDB的读写权限
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "lambda_dynamodb_policy"
  description = "IAM policy for Lambda to allow access to DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ],
        Effect = "Allow",
        Resource = aws_dynamodb_table.sample_table.arn
      },
    ],
  })
}

# 将策略附加到角色
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# 创建Lambda函数
resource "aws_lambda_function" "sample_lambda" {
  function_name = "SampleLambdaFunction"
  handler       = "index.handler"
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "nodejs12.x"

  source_code_hash = filebase64sha256("lambda_function_payload.zip")
  filename         = "lambda_function_payload.zip"
}

# Lambda函数代码包（lambda_function_payload.zip）需要自己做，这里只是示例整个过程，不提供代码