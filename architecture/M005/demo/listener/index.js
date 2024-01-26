const crypto = require('crypto');
const fetch = require('node-fetch');
const XmlBuilder = require("xmlbuilder");
const xml2js = require('xml2js');

exports.handler = async function (req, resp, context) {
    const params = {
        MessageBody: JSON.stringify(req.queries),
        QueueUrl: process.env.QUEUE_URL,
        Credentials: context.credentials
    };
    console.log('准备发送', params.QueueUrl, params.MessageBody);
    const data = await sendMessage(params);
    console.log('发送结果', data);
    if(data.Message.MessageId!=null){
        resp.send('消息发送完毕！消息ID：'+ data.Message.MessageId)
    } else {
        resp.send('消息发送失败！返回内容：'+ JSON.stringify(data.Message))
    }
};

async function sendMessage(params) {
    const { MessageBody, QueueUrl, Credentials } = params
    const { accessKeyId, accessKeySecret, securityToken } = Credentials
    const url = new URL(QueueUrl);
    const body = XmlBuilder.create({
        Message:{
            MessageBody: MessageBody
        }
    }).toString()
    const headers = {
        "Host":url.host,
        "Date": (new Date()).toUTCString(),
        "User-Agent": "Node/" + process.version + " (" + process.platform + ")",
        "Content-MD5": crypto.createHash("md5").update(Buffer.from(body, 'utf-8')).digest("base64"),
        "Content-Length": Buffer.from(body, 'utf-8').length,
        "Content-Type": "text/xml;charset=utf-8",
        "Security-Token": securityToken,
        "x-mns-version": "2015-06-06"
    };
    headers.Authorization = `MNS ${accessKeyId}:${crypto.createHmac("sha1", accessKeySecret).update(`POST\n${headers['Content-MD5']}\n${headers['Content-Type']}\n${headers.Date}\nx-mns-version:2015-06-06\n${url.pathname}`).digest('base64')}`;
    const response = await fetch(QueueUrl, { headers: headers, method: 'POST', body: body });
    const result = await response.text();
    const data = await xml2js.parseStringPromise(result)
    return data
}