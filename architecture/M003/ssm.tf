# Terraform 配置
terraform {
  // 定义所需的提供者
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud" // 使用腾讯云提供者
      version = "1.81.60"                        // 版本号
    }
  }
}

# 获取用户信息
data "tencentcloud_user_info" "info" {}

# 定义本地变量
locals {
  app_id         = data.tencentcloud_user_info.info.app_id    // 用户应用ID
  owner_uin      = data.tencentcloud_user_info.info.owner_uin // 用户唯一标识符
  region         = "ap-shanghai"                              // 创建资源的地域
  secret_name    = "dbinfo"                                   // 凭据名称
  secret_version = "v1"                                       // 凭据版本
  secret_string  = "{\"1password\":\"***\"}"                  // 凭据内容
  role_name      = "APPNAME_ROLE"                             // 用户角色
}

# 定义腾讯云提供者
provider "tencentcloud" {
  region = local.region // 使用本地变量中定义的地域
}

# 创建SSM秘密
resource "tencentcloud_ssm_secret" "appsecret" {
  secret_name = local.secret_name    // 使用本地变量中定义的凭据名称
  description = "这是为应用程序提供的数据库连接信息。" // 描述信息
  is_enabled  = true                 // 启用状态
}

# 创建SSM秘密版本
resource "tencentcloud_ssm_secret_version" "appsecret_info" {
  secret_name   = tencentcloud_ssm_secret.appsecret.secret_name // 使用SSM秘密的名称
  version_id    = local.secret_version                          // 使用本地变量中定义的版本ID
  secret_string = local.secret_string                           // 使用本地变量中定义的凭据内容
}

# 创建CAM策略
resource "tencentcloud_cam_policy" "ssm_policy" {
  name = "ssm_policy" // 策略名称
  // 策略内容
  document = <<EOF
  {
    "version": "2.0",
    "statement": [
        {
            "effect": "allow",
            "action": [
                "ssm:GetSecretValue"
            ],
            "resource": [
                "qcs::ssm::uin/${local.owner_uin}:secret/creatorUin/${local.owner_uin}/${local.secret_name}"
            ]
        }
    ]
  }
  EOF
}

# 创建CAM角色
resource "tencentcloud_cam_role" "role" {
  name             = local.role_name // 使用本地变量中定义的角色名称
  console_login    = false           // 控制台登录状态
  session_duration = 7200            // 会话持续时间
  // 角色内容
  document = <<EOF
  {
    "version":"2.0",
    "statement":[
        {
            "action":"name/sts:AssumeRole",
            "effect":"allow",
            "principal":{
                "service":[
                    "cvm.qcloud.com",
                    "scf.qcloud.com"
                ]
            }
        }
    ]
  }
  EOF
}

# 创建CAM角色策略附件
resource "tencentcloud_cam_role_policy_attachment" "role_policy_attachment_basic" {
  role_id   = tencentcloud_cam_role.role.id         // 使用CAM角色的ID
  policy_id = tencentcloud_cam_policy.ssm_policy.id // 使用CAM策略的ID
}

# 创建腾讯云实例，这里只是提供一个示例，具体的需要自己确认
# resource "tencentcloud_instance" "cvm" {
#   cam_role_name = tencentcloud_cam_role.role.name // 使用CAM角色的名称
# }