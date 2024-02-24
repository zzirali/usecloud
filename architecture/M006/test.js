const https = require('https');
const async = require('async');

const url = 'https://example.cn-hangzhou.fcapp.run'; // 请求URL
const concurrency = 10;  // 并发请求的数量
const totalRequests = 10;  // 请求总数

let completedRequests = 0;
let failedRequests = 0;
let startTime = Date.now();
const makeRequest = callback => {
    const stime = Date.now()
    https.get(url, res => {
        let data = '';
        res.on('data', chunk => { data += chunk; });
        res.on('end', () => {
            completedRequests++;
            console.log(`${completedRequests}\t耗时时长：${Date.now() - stime}`)
            callback(null, `耗时时长：${Date.now() - stime} -> ${data}`);
        });
    }).on('error', err => {
        failedRequests++;
        callback(err, null);
    });
};

const results = [];

async.timesLimit(totalRequests, concurrency, (n, next) => {
    makeRequest((err, result) => {
        if (err) {
            return next(err);
        }
        results.push(result);
        next();
    });
}, err => {
    if (err) {
        console.error('发生错误:', err);
    } else {
        let endTime = Date.now();
        console.log(`完成请求: ${completedRequests}`);
        console.log(`失败请求: ${failedRequests}`);
        console.log(`总耗时: ${(endTime - startTime) / 1000}秒`);
        console.log('返回内容', results)
    }
});