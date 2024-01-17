<h2 align="center">

一个不完美的云原生实践，无奈的选择

</h2>

- [公众号文章链接](https://mp.weixin.qq.com/s/G-_1y-uAtd_PwF-X1zjhbQ)

##### 第一部分AWS的案例

如果只要求计算服务（假设是一个云函数）中的应用程序，只具有数据库的一个特定库表的访问权限。在 AWS 中，我可以直接用 IAM 来管理，tf 配置文件的[地址](./aws.tf)

##### 第二部分腾讯云密钥操作

1. 创建 SSM 凭证，并在其中建一个版本，设置密钥信息。
2. 为目标应用负载创建角色，并为这个角色添加仅访问此 SSM 凭证的 API 权限，最后绑定角色到目标负载中。
3. 在应用中编写代码，初始化时调用 SSM 凭证的 API，获取凭证

其中 1-2 步，如果你是个人开发者，产品很小可以在控制台中点点点（我上面特意给出了指引文档，你可以试一试），或者用我推荐的 IaC [配置文件](./ssm.tf)的形式来完成这些过程，用于批量和自动化工作中。

配置的内容是：

1. 在 SSM 中创建了一个名字为`dbinfo`的凭据，并在这个凭据中设置了`v1`版本的密钥内容，内容是一个示例`{"1password":"***"}`(你可以将其替换为数据库信息或者任意格式的 API 密钥)；
2. 创建了一个策略，名称为`ssm_policy`，策略内容是限定了仅可以访问`dbinfo`凭据明文，具体的策略如下：

```json
// 标准JSON没有注释，这里只是为了表达，使用时需要自行去除
// 凭据的CAM配置文档 https://cloud.tencent.com/document/product/598/70019
{
    "version": "2.0", // 默认2.0的策略语言版本
    "statement": [
        {
            "effect": "allow", // 允许设定
            "action": [ // 行为列表
                "ssm:GetSecretValue" // 获取凭证明文的接口声明
            ],
            "resource": [ // 资源边界
                // 凭据的资源六段式
                "qcs::ssm::uin/${owner_uin}:secret/creatorUin/${owner_uin}/dbinfo"
            ]
        }
    ]
  }
```

3. 创建一个角色，名称为 `APPNAME_ROLE`，这个角色是基于资源的角色，授权给 `CVM 服务器` 和 `SCF 云函数`两个产品。

```json
// 标准JSON没有注释，这里只是为了表达，使用时需要自行去除
// 临时凭证申请文档 https://cloud.tencent.com/document/product/1312/48197
{
    "version":"2.0",
    "statement":[
        {
            "action":"name/sts:AssumeRole", // 临时凭证申请
            "effect":"allow", // 控制允许
            "principal":{ // 哪些主体可以扮演这个角色
                "service":[ // 服务主体
                    "cvm.qcloud.com", // 云服务器
                    "scf.qcloud.com" // 云函数
                ]
            }
        }
    ]
  }
```

`name/sts:AssumeRole` 允许指定的服务或实体假设（Assume）一个 `CAM 角色`。

我这里配置的是，允许`CVM服务器`和`SCF云函数`两个服务可以假设这个角色。我在后面的应用部署中，可以临时授予应用负载（必须是上面两个服务的一种）这个角色，让它临时拥有此角色的权限，而不是在应用中用 AK/SK 的形式永久的授予权限，有助于实现最小权限原则，提高安全性。

**关于这一点我在前两篇的文章中也提到了，但是并没有讲的很细。在这里详细描述一下，如果必要我后面单独开一篇来讲这个。**

4. 将 `ssm_policy` 策略绑定到 `APPNAME_ROLE` 角色，使其拥有获取 SSM 凭证的权限。

5. 最后为 `CVM服务器` 或 `SCF云函数` 实例授予`APPNAME_ROLE` 角色，整体配置就就完成了。

接下来在应用中，需要编写代码来获取凭证。这里由于大家的开发语言五花八门，我就不阐述具体的实现了，按照这两个文档来实现就行：

- 获取实例元数据： https://cloud.tencent.com/document/product/213/4934
- 获取凭据明文：https://cloud.tencent.com/document/product/1140/40522

如果你使用 `nodejs`，可以参考下列代码：

- `index.js` 文件：[链接](./db/index.js)
- `cloud.js` 文件，[链接](./db/cloud.js)，这个文件是我自己封装的，为的是抹平不同云的实现差异，这里我是从生产环境中拿下来删减的，只包含必要的 SSM 凭证获取内容。