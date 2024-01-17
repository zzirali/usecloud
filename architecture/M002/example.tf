provider "tencentcloud" {
  region     = "ap-guangzhou"
}

# 创建COS存储桶
resource "tencentcloud_cos_bucket" "bucket" {
  bucket = "test"
  acl    = "private"
}

# 创建策略
resource "tencentcloud_cam_policy" "policy" {
  name     = "cos_rw_policy"
  document = <<EOF
  {
    "version": "2.0",
    "statement": [
      {
        "effect": "allow",
        "action": [
          "name/cos:GetObject",
          "name/cos:PutObject",
          "name/cos:DeleteObject"
        ],
        "resource": ["${tencentcloud_cos_bucket.bucket.id}/*"]
      }
    ]
  }
  EOF
}

# 创建角色并绑定策略
resource "tencentcloud_cam_role" "role" {
  name          = "cos_rw_role"
  document      = <<EOF
  {
    "version": "2.0",
    "statement": [
      {
        "action": "sts:AssumeRole",
        "effect": "allow",
        "principal": {
          "service": ["cvm.tencentcloudapi.com"]
        }
      }
    ]
  }
  EOF
  description   = "role for cvm to access cos"
  console_login = true
}

resource "tencentcloud_cam_role_policy_attachment" "attachment" {
  role_id  = tencentcloud_cam_role.role.id
  policy_id = tencentcloud_cam_policy.policy.id
}

# 创建服务器并绑定角色
# 此部分只展示关键的角色授予，其他的内容请按照自己的情况配置
resource "tencentcloud_instance" "instance" {
  cam_role_name              = tencentcloud_cam_role.role.name
}