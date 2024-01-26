exports.handler = async function(event, context, callback) {
    event = JSON.parse(event.toString());
    console.log('原始数据：', event);
    if(Array.isArray(event)){
        for (const record of event) {
            const { messageBody, messageId } = record.data
            console.log(`处理消息ID: ${messageId}，消息内容：${JSON.stringify(messageBody)}`);
            await timeout()
            console.log(`处理消息ID: ${messageId}，完毕！`);
        }
    } else {
        const { messageBody, messageId } = event.data??{}
        console.log(`处理消息ID: ${messageId}，消息内容：${JSON.stringify(messageBody)}`);
        await timeout()
        console.log(`处理消息ID: ${messageId}，完毕！`);
    }
    callback(null, 'succ')
};

function timeout(){
    return new Promise(resolve=>{
        setTimeout(function(){
            resolve(true)
        },3000)
    })
}