const mysql = require('mysql');
const Cloud = require('./cloud.js');

const DATABASE = 'information_schema'

const cloud = new Cloud({
    camName:'APPNAME_ROLE' // 角色的名称
});

async function test(){
    const info = await cloud.getMysqlInfo('ap-shanghai',['AppMySql','mysql-address:1.0']) // 上海地域，凭据名称:版本号
    if(info.Code=='Success'){
        // 这里我设置的凭据是json字符串，你需要自己确定凭据内容规范，以避免解析不正确的情况
        const connection = await mysql.createConnection({
            host: info.Data.host,
            user: info.Data.UserName,
            password: info.Data.Password,
            port: info.Data.port,
            database: DATABASE
        });
        connection.query('SELECT 1', function (error, results, fields) {
            if (error) {
                console.log('数据库连接失败: ', error.toString());
            } else {
                console.log('数据库连接成功: ', results);
            }
            connection.end();
        })
    } else {
        console.log('初始化获取数据库密码失败！无法启动项目')
        // 这里可以做告警机制，寻求人工干预
    }
}

test()