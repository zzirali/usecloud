<h2 align="center">

当AWS账单超出预算时，如何自动化处理资源实例？

</h2>

- [公众号文章链接](https://mp.weixin.qq.com/s/zAMuQ29Xp7DnDE74RqffnQ)


由于每个开发者的预算计划不同，因此我在这里不涉及预算创建部分，只给出从 SNS 到 Lambda 的代码。

假设我在收到预算告警时，要删除同地域指定的 EC2 服务器实例（这是一个非常极端的例子）

1. terraform 配置，默认在 AWS 新加坡地域，如果你要在 AWS 中国，请更改 `locals.global` 为 `aws-cn`），[代码地址](./price.tf)

2. `price_exec.zip` Lambda 函数压缩包，只包含一个 `index.mjs` 文件。[代码地址](./index.mjs)

这里 Lambda 函数使用 aws-sdk 来删除指定的 EC2 实例，这需要 Lambda 函数具备可以删除 EC2 实例的权限，所以对应的在 terraform 配置中，我添加了相关的策略。

```
{
   "Effect" : "Allow",
   "Action" : "ec2:TerminateInstances",
   "Resource" : "${format("arn:%s:ec2:%s:%s:*", local.global, local.region, data.aws_caller_identity.current.account_id)}"
}
// 这里可以删除所在地域的所有EC2实例，如果你能确定特定的实例，则可以继续缩小边界。
```

如果你要复用替换为其他的服务，需要**遵守最小权限原则**配置好相应的权限。

如果你想执行发送邮件或者发送消息到社交软件中，请按照相关的开发指引自行编写相应的 Lambda 代码。你可以创建多个 Lambda 函数，共同订阅同一个 SNS 主题。
