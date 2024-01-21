const AWS = require('aws-sdk');
const sqs = new AWS.SQS();

exports.handler = async (event) => {
    const params = {
        MessageBody: JSON.stringify(event),
        QueueUrl: process.env.SQS_QUEUE_URL
    };
    try {
        const data = await sqs.sendMessage(params).promise();
        console.log(`MessageID is ${data.MessageId}`);
        return { statusCode: 200, body: '消息发送完毕！' };
    } catch (error) {
        console.error(error);
        return { statusCode: 500, body: '发生错误！'+ error.toString() };
    }
};