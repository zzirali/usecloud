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
getMetaInfo(`cam/security-credentials/cos_rw_role`).then(console.log)