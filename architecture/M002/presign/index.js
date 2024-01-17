const crypto = require('crypto')
const globalInfo = {}
const config = {
    cam: 'CVM-N', // 需要替换，绑定服务器的角色
    bucket: 'test', // 需要替换，目标对象存储桶，不包含后面的appid
    cosurl: null, // 如果对象存储桶配置自定义域名，可以填
    region: 'ap-guangzhou' // 对象存储桶所在地域
}

async function getGlobalInfo(){
    if(globalInfo.appid==null){
        globalInfo.appid = await getMetaInfo('app-id')
    }
    if(globalInfo.secretId==null|| globalInfo.expiredTime-30<(new Date().getTime()/1000)){
        const credential = await getMetaInfo(`cam/security-credentials/${config.cam}`)
        if(typeof credential === 'object' && credential.Code==='Success'){
            globalInfo.token = credential.Token
            globalInfo.secretId = credential.TmpSecretId
            globalInfo.secretKey = credential.TmpSecretKey
            globalInfo.expiredTime = credential.ExpiredTime
        }
    }
    return globalInfo
}

async function getMetaInfo(key){
    try{
        const response = await fetch(`http://metadata.tencentyun.com/latest/meta-data/${key}`)
        try{
            return await response.json()
        } catch(e){
            return await response.text()
        }
    } catch(e){
        return {
            Code: "Error",
            Data: e.toString()
        }
    }
}

async function getCredential(options){
    const params = {
        Action: 'GetFederationToken',
        Version: '2018-08-13',
        Name: 'cos-sts',
        Region: options.region ?? 'ap-beijing',
        SecretId: options.secretId,
        Token: options.token,
        Timestamp:  parseInt(+new Date() / 1000),
        Nonce: Math.round((1 + Math.random()) * 10000),
        DurationSeconds: options.durationSeconds ?? 1800,
        Policy: encodeURIComponent(JSON.stringify(options.policy))
    };
    params.Signature =  crypto.createHmac('sha1', options.secretKey).update(Buffer.from('POSTsts.tencentcloudapi.com/?' + Object.keys(params).sort().map(function(item) { return item + '=' + (params[item] || '')}).join('&'), 'utf8')).digest('base64')
    return new Promise((resolve)=>{
        fetch('https://sts.tencentcloudapi.com', {
            headers: {
                Host: 'sts.tencentcloudapi.com',
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            method: 'POST',
            body: new URLSearchParams(params).toString()
        }).then(response => {
            response.json().then(data=>{
                const info = data.Response
                resolve({
                    StartTime: info.ExpiredTime - (options.durationSeconds ?? 1800),
                    ...info
                })
            }).catch(()=>{
                resolve({
                    Code: "Fail"
                })
            })
        }).catch(error => {
            resolve({
                Code: "Error",
                Data: error.toString()
            });
        })
    })
}

async function getuploadUrl(path='test.json', durationSeconds = 60) {
    const { bucket, region, cosurl } = config
    const { appid, secretId, secretKey, token } = await getGlobalInfo()
    const { StartTime, ExpiredTime, Credentials, Expiration } = await getCredential({
        secretId: secretId,
        secretKey: secretKey,
        token: token,
        durationSeconds: durationSeconds,
        region: region,
        policy: {
            version: '2.0',
            statement: [{
                action: [
                    'name/cos:PostObject'
                ],
                effect: 'allow',
                principal: { qcs: ['*'] },
                resource: [
                    `qcs::cos:${region}:uid/${appid}:prefix//${appid}/${bucket}/${path}`
                ]
            }]
        }
    })
    const { TmpSecretKey, TmpSecretId, Token } = Credentials
    const keytime = `${StartTime};${ExpiredTime}`
    const policy = `{"expiration": "${Expiration}","conditions": [{ "q-sign-algorithm": "sha1" },{ "q-ak": "${TmpSecretId}" },{ "q-sign-time": "${keytime}" }]}`
    const keysign = crypto.createHmac('sha1', TmpSecretKey).update(keytime).digest('hex')
    const tosign = crypto.createHash('sha1').update(policy).digest('hex')
    const signature = crypto.createHmac('sha1', keysign).update(tosign).digest('hex')
    return JSON.stringify({
        url: cosurl||`https://${bucket}-${appid}.cos.${region}.myqcloud.com`,
        form: {
            key: path,
            policy: Buffer.from(policy, 'utf-8').toString('base64'),
            'q-sign-algorithm': 'sha1',
            'q-ak': TmpSecretId,
            'q-key-time': keytime,
            'q-signature': signature,
            'x-cos-security-token': Token,
            'success_action_status': 200,
            'Content-Type': ''
        }
    })
}

getuploadUrl().then(console.log)
// getuploadUrl(‘/asset/test.json’).then(console.log)