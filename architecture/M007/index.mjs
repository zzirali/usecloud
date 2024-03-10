// 导入AWS SDK中的EC2客户端和终止实例命令
import { EC2Client, TerminateInstancesCommand } from '@aws-sdk/client-ec2';
// 初始化EC2客户端
const ec2Client = new EC2Client({});

// 定义异步处理函数，用于处理SNS通知事件
export async function handler(event) {
    // 打印接收到的SNS通知内容
    console.log('SNS通知内容',JSON.stringify(event))
    // 从环境变量中获取需要终止的EC2实例ID
    const instanceId = process.env.INSTANCE_ID;
    // 打印计划终止的实例ID
    console.log('计划终止实例ID', instanceId)
    // 创建终止实例的命令，指定要终止的实例ID
    const command = new TerminateInstancesCommand({
        InstanceIds: [ instanceId ],
    });
    try {
        // 发送终止实例的命令，并等待结果
        const data = await ec2Client.send(command);
        // 打印终止实例成功的消息和返回的数据
        console.log("终止实例成功：", data);
        // 返回成功的状态码和数据
        return { code: 0, data };
    } catch (error) {
        // 捕获到错误时，打印错误信息
        console.error("终止实例失败：", error);
        // 返回失败的状态码和错误信息
        return { code: -1, error: error.toString() };
    }
};