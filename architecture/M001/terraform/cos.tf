terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "1.81.60"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

data "tencentcloud_user_info" "info" {}

locals {
  app_id       = data.tencentcloud_user_info.info.app_id
  owner_uin    = data.tencentcloud_user_info.info.owner_uin
  region       = "ap-shanghai"                  // 希望创建资源的地域
  domain       = "www.example.com"              // 绑定的自定义域名
  index_name   = "index.html"                   // 访问中间页路径
  index_file   = "${path.module}/index.html"    // 访问中间页文件
  example_id   = "0"                            // 示例参数
  example_name = "asset/0.json"                 // 示例配置路径
  example_file = "${path.module}/set.json"      // 示例配置文件
  cert         = file("${path.module}/ssl.crt") // 自定义域名证书crt文件
  private_key  = file("${path.module}/ssl.key") // 自定义域名证书key文件
}

provider "tencentcloud" {
  region = local.region
}

data "tencentcloud_cdn_domain_verifier" "shop_cdnvr" {
  domain        = local.domain
  auto_verify   = true
  freeze_record = true
}

resource "null_resource" "check_verification" {
  count = data.tencentcloud_cdn_domain_verifier.shop_cdnvr.verify_result ? 0 : 1
  provisioner "local-exec" {
    command = "echo '需要进行${data.tencentcloud_cdn_domain_verifier.shop_cdnvr.record_type}解析验证｜${data.tencentcloud_cdn_domain_verifier.shop_cdnvr.sub_domain} | ${data.tencentcloud_cdn_domain_verifier.shop_cdnvr.record}' && exit 1"
  }
}

resource "tencentcloud_cos_bucket" "shop_bucket" {
  bucket      = "shop-${local.app_id}"
  acl         = "private"
  multi_az    = true
  force_clean = true
  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

resource "tencentcloud_cos_bucket_policy" "cos_policy" {
  bucket = tencentcloud_cos_bucket.shop_bucket.id

  policy = <<EOF
  {
    "Statement": [
      {
        "Principal": {
          "qcs": [
            "qcs::cam::uin/${local.owner_uin}:service/cdn"
          ]
        },
        "Effect": "Allow",
        "Action": [
          "name/cos:GetObject",
          "name/cos:HeadObject",
          "name/cos:OptionsObject"
        ],
        "Resource": [
          "qcs::cos:ap-shanghai:uid/${local.app_id}:${tencentcloud_cos_bucket.shop_bucket.id}/*"
        ]
      }
    ],
    "version": "2.0"
  }
  EOF
}

resource "tencentcloud_cos_bucket_object" "upload_index" {
  bucket = tencentcloud_cos_bucket.shop_bucket.id
  acl    = "private"
  key    = local.index_name
  source = local.index_file
}

resource "tencentcloud_cos_bucket_object" "upload_example" {
  bucket = tencentcloud_cos_bucket.shop_bucket.id
  acl    = "private"
  key    = local.example_name
  source = local.example_file
}

resource "tencentcloud_cdn_domain" "shop_cdn" {
  depends_on   = [null_resource.check_verification]
  domain       = local.domain
  service_type = "web"
  area         = "mainland"
  cache_key {
    full_url_cache = "off"
  }

  origin {
    origin_type          = "cos"
    origin_list          = ["${tencentcloud_cos_bucket.shop_bucket.id}.cos-website.${local.region}.myqcloud.com"]
    server_name          = "${tencentcloud_cos_bucket.shop_bucket.id}.cos-website.${local.region}.myqcloud.com"
    origin_pull_protocol = "follow"
    cos_private_access   = "on"
  }

  rule_cache {
    cache_time  = 86400
    rule_type   = "all"
    rule_paths  = ["*"]
    switch      = "on"
    re_validate = "on"
  }

  compression {
    switch = "on"
    compression_rules {
      algorithms = ["gzip"]
      compress   = true
      max_length = 2097152
      min_length = 256
      rule_paths = ["js", "html", "css", "xml", "shtml", "htm", "json"]
      rule_type  = "file"
    }
  }

  https_config {
    https_switch = "on"
    http2_switch = "on"
    force_redirect {
      switch               = "on"
      redirect_type        = "https"
      redirect_status_code = 302
    }
    ocsp_stapling_switch = "on"
    server_certificate_config {
      message             = "自上传证书"
      certificate_content = local.cert
      private_key         = local.private_key
    }
    verify_client = "off"
  }
}

output "manage_url" {
  value       = "https://cosbrowser.cloud.tencent.com/editor?bucket=${tencentcloud_cos_bucket.shop_bucket.id}&region=ap-shanghai"
  description = "存储桶文件管理地址"
}

output "dns_cname" {
  value       = tencentcloud_cdn_domain.shop_cdn.cname
  description = "域名cname解析内容"
}

output "wxapp_url" {
  value       = "直接看github的wxapp目录内容"
  description = "微信小程序代码片段"
}

output "scan_url" {
  value       = "https://${local.domain}/${local.example_id}"
  description = "在小程序后台配置二维码扫描后，将此路径制作成二维码，用微信扫码观看效果"
}