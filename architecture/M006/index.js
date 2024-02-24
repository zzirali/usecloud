exports.handler = (req, resp, context) => {
    let num = 0
    const starttime = new Date().getTime()
    for(let i=0; i<1000000000;i++){
      num+=i
    }
    resp.send(JSON.stringify({ data: num, time: new Date().getTime() - starttime }))
}