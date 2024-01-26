<h2 align="center">

深度解析消息队列服务｜从 AWS SQS 到阿里云 MNS

</h2>

- [公众号文章链接](https://mp.weixin.qq.com/s/-cvD5F8fcge6DyiaEKhXWw)


`阿里云 MNS` 的开箱配置，其中消息生产者和消费者使用了 `阿里云函数计算 FC`，跟`AWS`的 DEMO 保持一致。

#### 1. terraform 配置[链接](./demo/iac/demo.tf)

函数计算里绑定了一个 RAM 角色，并赋予了消息服务 MNS 的权限，这样后面我就可以直接用角色资源鉴权，免除 AK/SK。

这里有两个点需要注意：

1. 函数计算 FC 我没有配日志，日志这里需要自己建主题或者和其他函数服务共用，可以在开头填写对应的日志主题名称；
2. `MNS`、`FC`、`EventBridge` 可能需要提前开通，否则会有资源创建问题。

除了 `tf配置`，还需要下面两个函数代码包。[listener.zip](./demo/iac/listener.zip)，[processor.zip](./demo/iac/processor.zip)。其中 `listener.zip` 需要安装依赖后再上传。

#### 2. Listener 函数

HTTP 触发的函数，每次触发都会自动把 get 参数作为消息传入消息队列。

- [**index.js 文件**](./demo/listener/index.js)：这里我没用 SDK（MNS 文档里不提供 nodejs 版本，并且 github 上的有点过于老了），直接自己拼了签名。

- [**package.json**](./demo/listener/package.json)：上传函数代码包前需要先安装依赖，因为运行时是 nodejs16，所以没有 `fetch` 这些函数模块。

#### 3. Processor 函数

- [**index.js 文件**](./demo/processor/index.js)：消息服务 MNS 队列驱动触发的函数，消息队列存在消息时，会自动调用该函数处理，这里只是一个示例，每条消息延迟 3 秒钟返回。

