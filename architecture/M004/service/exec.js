const AWS = require('aws-sdk');
const sqs = new AWS.SQS({ region: 'ap-southeast-1' }); // 初始化SQS消息队列客户端
const queueUrl = "https://sqs.ap-southeast-1.amazonaws.com/0/queue"; // SQS消息队列URL

async function processMessages() {
    console.log(new Date().getTime(),'开始新一轮处理！')
    let data = await sqs.receiveMessage({ // 监听接收消息
        QueueUrl: queueUrl,
        MaxNumberOfMessages: 1, // 每次只能处理一条
        WaitTimeSeconds: 20 // 有消息并达到MaxNumberOfMessages数量后立刻返回，无消息最长20秒
    }).promise();
    if (data.Messages.length != 0) {
        let message = data.Messages[0];
        console.log(new Date().getTime(),'处理消息: ', message.MessageId);
        // 调用上游API服务，大约2秒处理
        // ...
        // 发送邮件信息
        await sqs.deleteMessage({ // 消息已经消费，删除消息
            QueueUrl: queueUrl,
            ReceiptHandle: message.ReceiptHandle
        }).promise();
    }
    return;
}

async function run() {
    while (true) { // 轮询监听
        await processMessages();
    }
}

run().catch(console.error);