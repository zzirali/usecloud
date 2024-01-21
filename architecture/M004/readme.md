<h2 align="center">

当上游服务拉跨时，如何设计服务架构？

</h2>

- [公众号文章链接](https://mp.weixin.qq.com/s/wB1OCum0ehYWEQ-zrRZmUA)

##### 案例相关的代码

启动一个`EC2服务器`或 `Fargate引擎`（取决于价格因素）运行查询服务，在服务中轮询消息队列，**当消息队列有数据时，进行查询处理和发邮件的流程，并标记消息已消费，然后继续轮询消息队列，直到下个消息到来。**[nodejs例子地址](./service/exec.js)

这个案例的接收查询请求的 lambda 函数代码，以及处理查询的服务代码因为没有多大的通用性，就不提供了，只提供在 AWS 中的 `tf 配置`，给大家展示全部服务的关联组成。[tf配置文件](./service/example.tf)

##### 消息队列DEMO

我自己整理了一个在 `AWS` 运行的开箱即用的架构配置。如果你感兴趣的话可以从这里开始实践一下，然后按照自己的需求自己修改生产和消费的逻辑。

首先是 [tf配置文件](./demo/iac/demo.tf)，由于 `AWS` 分为国际区和中国区，我给的配置是国际区的，如果你要在中国区运行，需要注意以下几项：

1. `locals.global` 需要改为 `aws-cn`，并且初始认证时需要中国区的账号
2. 中国区 `API Gateway` 需要在备案通过后才能访问，否则会一直返回权限问题。

另外 `tf配置` 中，还有两个 `lambda代码包`，我这里用的 `nodejs` 环境，两个代码内容如下：

- **http_listener**：这里用的时候需要自己做一下依赖配置。[代码地址](./demo/listener/index.js)
- **sqs_processor**：只有一个打印消息，SQS 有自动确认机制，因此不需要我们手动确认。[代码地址](./demo/processer/index.js)

上面两个代码产物分别 zip 压缩打包，放置 `tf配置` 同级目录下 ，接着跑一下 `tf配置`，你可以直接下载[IaC目录](./demo/iac/)内容，直接跑配置。

```bash
terraform init
terraform apply
```
