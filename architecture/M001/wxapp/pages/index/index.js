const scanurl = 'https://www.example.com/' // 扫码进入的路径
const asseturl = (id) => `https://www.example.com/asset/${id}.json` // 配置文件的路径生成函数
const defaultvalue = 0 // 当扫码路径不存在时应该提供的默认配置

const app = getApp()
let that = null
Page({
  data: {
    loading: true,
    loadtips: '加载中',
    data: {}
  },
  async onLoad(options) {
    that = this
    const value = (options.q || '').replace(encodeURIComponent(scanurl), '')
    getinfo(value)
  }
})

async function getinfo(value = '') {
  let id = parseInt(value)
  try {
    if (isNaN(id)) id = defaultvalue
    const text = await downLoad(asseturl(id), function (tip) {
      that.setData({
        loadtips: `已加载 ${tip}%`
      })
    })
    that.setData({
      loading: false,
      data: JSON.parse(text)
    })
  } catch (e) {
    console.log(e)
    if(id !== defaultvalue){
      getinfo()
    } else {
      that.setData({
        loading: true,
        loadtips: `信息加载异常`
      })
    }
  }
}

function downLoad(file, func) {
  return new Promise((resolve, reject) => {
    const downloadTask = wx.downloadFile({
      url: file,
      success(res) {
        if (res.statusCode === 200) {
          const name = res.tempFilePath
          const jsonraw = wx.getFileSystemManager();
          const tempdata = jsonraw.readFileSync(name, "utf-8")
          resolve(tempdata)
        } else {
          reject('文件下载失败')
        }
      },
      fail(e) {
        reject('文件下载失败')
      }
    });
    downloadTask.onProgressUpdate((res) => {
      typeof func === 'function' ? func(res.progress) : null
    })
  })
}