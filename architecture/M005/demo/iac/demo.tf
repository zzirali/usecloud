locals {
  region  = "cn-hangzhou"
  logname = "*" // 函数计算服务挂载的日志主题名
}

provider "alicloud" {
  region = local.region
}

data "alicloud_account" "current" {}

// 创建一个MNS队列
resource "alicloud_mns_queue" "query" {
  name                     = "testquery"
  delay_seconds            = 0
  maximum_message_size     = 65536
  message_retention_period = 345600
  visibility_timeout       = 30
  polling_wait_seconds     = 0
}

// 创建一个RAM角色，供FC函数使用
resource "alicloud_ram_role" "fc_exec_role" {
  name        = "fc-exec-role"
  description = "专门的用于操作队列的函数计算FC角色"
  document    = <<EOF
  {
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": [
            "fc.aliyuncs.com"
          ]
        }
      }
    ],
    "Version": "1"
  }
  EOF
}

// 创建一个RAM策略，允许FC函数操作MNS队列和写入日志
resource "alicloud_ram_policy" "fc_exec_policy" {
  policy_name     = "fc-exec-policy"
  description     = "可以操作MNS队列和写入日志的权限策略"
  policy_document = <<EOF
  {
    "Version": "1",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "mns:SendMessage",
          "mns:ReceiveMessage",
          "mns:DeleteMessage"
        ],
        "Resource": [
          "acs:mns:${local.region}:${data.alicloud_account.current.id}:/queues/${alicloud_mns_queue.query.name}/*"
        ]
      },
      {
        "Effect":"Allow",
        "Action":[
          "log:*"
        ],
        "Resource":[
          "acs:log:${local.region}:${data.alicloud_account.current.id}:project/${local.logname}/*",
          "acs:log:${local.region}:${data.alicloud_account.current.id}:project/${local.logname}"
        ]
      }
    ]
  }
  EOF
}

// 将RAM策略附加到RAM角色
resource "alicloud_ram_role_policy_attachment" "fc_exec_policy_attach" {
  role_name   = alicloud_ram_role.fc_exec_role.name
  policy_name = alicloud_ram_policy.fc_exec_policy.policy_name
  policy_type = "Custom"
}

// 创建一个FC服务
resource "alicloud_fc_service" "testservice" {
  name            = "testservice"
  description     = "用于测试发送消息和消费消息的函数服务"
  internet_access = true
  role            = alicloud_ram_role.fc_exec_role.arn
}

// 创建一个FC函数，用于接收HTTP请求并发送MNS消息
resource "alicloud_fc_function" "listener" {
  service     = alicloud_fc_service.testservice.name
  description = "用于接收HTTP请求并发送MNS消息"
  name        = "listener"
  filename    = "listener.zip"
  handler     = "index.handler"
  runtime     = "nodejs16"
  memory_size = 128
  timeout     = 60
  environment_variables = {
    QUEUE_URL = "http://${data.alicloud_account.current.id}.mns.${local.region}.aliyuncs.com/queues/${alicloud_mns_queue.query.name}/messages"
    TZ        = "Asia/Shanghai"
  }
}

// 创建一个http触发器，用于url调用触发发送消息
resource "alicloud_fc_trigger" "httpstart" {
  service  = alicloud_fc_service.testservice.name
  function = alicloud_fc_function.listener.name
  name     = "httpstart"
  type     = "http"
  config   = <<EOF
  {
    "authType":"anonymous",
    "methods":["GET"],
    "disableURLInternet":false
  }
  EOF
}

// 创建一个FC函数，用于接收和处理MNS消息
resource "alicloud_fc_function" "processor" {
  service     = alicloud_fc_service.testservice.name
  description = "用于接收和处理MNS消息"
  name        = "processor"
  filename    = "processor.zip"
  handler     = "index.handler"
  runtime     = "nodejs16"
  memory_size = 128
  timeout     = 60
  environment_variables = {
    TZ = "Asia/Shanghai"
  }
}

// 创建一个eventbridge触发器，将MNS队列与MNS处理器FC函数关联起来
resource "alicloud_fc_trigger" "querystart" {
  service  = alicloud_fc_service.testservice.name
  function = alicloud_fc_function.processor.name
  name     = "querystart"
  type     = "eventbridge"
  config   = <<EOF
  {
    "triggerEnable":true,
    "asyncInvocationType":false,
    "eventSinkConfig":{
      "deliveryOption":{
        "mode":"event-streaming",
        "eventSchema":"CloudEvents"
      }
    },
    "eventSourceConfig":{
      "eventSourceType":"MNS",
      "eventSourceParameters":{
        "sourceMNSParameters":{
          "RegionId":"${local.region}",
          "QueueName":"${alicloud_mns_queue.query.name}"
        },
        "eventRuleFilterPattern":"{}"
      }
    },
    "runOptions":{
      "mode":"event-streaming",
      "errorsTolerance":"ALL",
      "retryStrategy":{
        "pushRetryStrategy":"BACKOFF_RETRY"
      },
      "deadLetterQueue":null,
      "batchWindow":{
        "countBasedWindow":1,
        "timeBasedWindow":0
      }
    }
  }
  EOF
}
