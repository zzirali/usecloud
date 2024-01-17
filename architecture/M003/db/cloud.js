const crypto = require('crypto');

class Cloud {
    constructor(config) {
        this.camName = config.camName ?? '';
        this.globalInfo = {};
    }

    async getGlobalInfo() {
        if (this.globalInfo.appid == null) {
            this.globalInfo.appid = await this.getMetaInfo('app-id')
        }
        if (this.globalInfo.secretId == null || this.globalInfo.expiredTime - 30 < (new Date().getTime() / 1000)) {
            const credential = await this.getMetaInfo(`cam/security-credentials/${this.camName}`)
            if (typeof credential === 'object' && credential.Code === 'Success') {
                this.globalInfo.token = credential.Token
                this.globalInfo.secretId = credential.TmpSecretId
                this.globalInfo.secretKey = credential.TmpSecretKey
                this.globalInfo.expiredTime = credential.ExpiredTime
            }
        }
        return this.globalInfo
    }

    async getMetaInfo(key) {
        try {
            const response = await fetch(`http://metadata.tencentyun.com/latest/meta-data/${key}`)
            try {
                return await response.json()
            } catch (e) {
                return await response.text()
            }
        } catch (e) {
            return {
                Code: "Error",
                Data: e.toString()
            }
        }
    }

    async sendRequest(url, params) {
        const { secretId, secretKey, token } = await this.getGlobalInfo()
        if (secretId == null) {
            return {
                Code: "Error",
                Data: "CAM role is not exists."
            }
        }
        const allParams = {
            ...params,
            SecretId: secretId,
            Token: token,
            Timestamp: parseInt(+new Date() / 1000),
            Nonce: Math.round((1 + Math.random()) * 10000),
        };
        const paramString = Object.keys(allParams).sort().map(item => item + '=' + (allParams[item] || '')).join('&');
        allParams.Signature = crypto.createHmac('sha1', secretKey).update(Buffer.from('POST' + url + '/?' + paramString, 'utf8')).digest('base64');

        try {
            const response = await fetch('https://' + url, {
                headers: {
                    Host: url,
                    'Content-Type': 'application/x-www-form-urlencoded'
                },
                method: 'POST',
                body: new URLSearchParams(allParams).toString()
            });
            const data = await response.json();
            const info = data.Response;
            if (info.Error == null) {
                return {
                    Data: info,
                    Code: 'Success'
                }
            } else {
                return {
                    Code: info.Error.Code,
                    Data: info.Error.Message
                };
            }
        } catch (error) {
            return {
                Code: "Error",
                Data: error.toString()
            };
        }
    }

    async getSecretValue(options) {
        const result = await this.sendRequest('ssm.tencentcloudapi.com', {
            Action: 'GetSecretValue',
            Version: '2019-09-23',
            Region: options.region ?? 'ap-shanghai',
            SecretName: options.secretName,
            VersionId: options.secretVersion ?? 'SSM_Current'
        });
        if (result.Code === 'Success') {
            try {
                return {
                    Code: "Success",
                    Data: JSON.parse(result.Data.SecretString ?? {})
                };
            } catch (e) {
                return {
                    Code: "ParseFail",
                    Data: e.toString()
                };
            }
        } else {
            return result;
        }
    }

    async getMysqlInfo(region, list = []) {
        const task = []
        for (const item of list) {
            const [name, version] = item.split(':')
            task.push(this.getSecretValue({
                region: region,
                secretName: name,
                secretVersion: version
            }))
        }
        const result = await Promise.all(task)
        let temp = {}
        for (const item of result) {
            if (item.Code == 'Success') {
                temp = Object.assign(temp, item.Data ?? {})
            } else {
                return item
            }
        }
        return {
            Code: "Success",
            Data: temp
        }
    }
}

module.exports = Cloud