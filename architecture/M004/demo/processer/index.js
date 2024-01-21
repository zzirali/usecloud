exports.handler = async (event) => {
    for (const record of event.Records) {
        const message = JSON.parse(record.body);
        console.log(`Received message: ${JSON.stringify(message)}`);
        // 这里可以处理消息
    }
};