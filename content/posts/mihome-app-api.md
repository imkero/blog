---
title: 米家 APP 网络请求的抓包、加解密与构造的代码笔记
categories:
  - 智能家居
tags:
  - 米家
  - 智能家居
excerpt: 本文介绍米家 APP 网络请求的抓包细节，并在前人经验与代码实现的基础上，整理了解密请求内容的 Python 实现以及自行构造米家 APP 网络请求的 JavaScript 实现。
date: 2022-05-29
---

## 参考资料

- [node-mihome](https://github.com/maxinminax/node-mihome)
- [xiaomi_miot_raw](https://github.com/ha0y/xiaomi_miot_raw/blob/master/custom_components/xiaomi_miot_raw/deps/xiaomi_cloud_new.py)
- [Xiaomi-cloud-tokens-extractor](https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor/blob/master/token_extractor.py)

## 概述

本文介绍米家 APP 网络请求的抓包细节，并在前人经验与代码实现的基础上，整理了解密请求内容的 Python 实现以及自行构造米家 APP 网络请求的 JavaScript 实现。

米家 APP 请求的后端 API 是在 HTTP POST JSON 请求的基础上增加了自有的请求签名以及一个可选的加密。在抓包获得请求与响应内容后，需要进行解密才能得到请求与响应的明文。而在自行构造发出请求时，可以只对请求进行签名以简化操作。

本文仅描述 Endpoint 为米家国内服务器（api.io.mi.com）的请求。其他地区的请求域名与请求内容可能有所不同。

## 抓包工具与环境

抓包条件要求：HTTPS 抓包。HTTPS 抓包的方法很多，本文不展开描述。笔者使用的抓包环境是 whistle + 夜神模拟器（设置 Android 系统的 Wi-Fi HTTP 代理）。

## 请求格式

```http
POST /app/miotspec/prop/get HTTP/2.0
host: api.io.mi.com
x-xiaomi-protocal-flag-cli: PROTOCAL-HTTP2
miot-encrypt-algorithm: ENCRYPT-RC4
miot-accept-encoding: gzip
content-type: application/x-www-form-urlencoded
content-length: <content-length>
cookie: <cookie>

data=...&rc4_hash__=...&signature=...&ssecurity=...&nonce=...
```

### 请求 Header

| 字段                   | 描述                                                                         |
| ---------------------- | ---------------------------------------------------------------------------- |
| miot-encrypt-algorithm | 可选，当存在且取值为 `ENCRYPT-RC4` 时，表示请求的 `data` 以及响应均需要加密  |
| miot-accept-encoding   | 可选，当存在且取值为 `GZIP` 时，表示允许服务端对响应的明文内容进行 gzip 压缩 |
| cookie                 | 包含登录态、地域、时区等的信息，下文详细描述                                 |

其他 Header 字段是固定值或常见值，这里不做赘述。

### Cookie

| 字段                   | 描述                                                     |
| ---------------------- | -------------------------------------------------------- |
| cUserId                | 登录态信息，登录时可以获得                               |
| serviceToken           | 登录态信息，登录时可以获得                               |
| yetAnotherServiceToken | 登录态信息，登录时可以获得，和 `serviceToken` 的取值一样 |
| countryCode            | 用户地区信息，国内用户一般为 `CN`                        |
| locale                 | 用户地区信息，国内用户一般为 `zh_CN`                     |
| timezone_id            | 时区信息，国内用户一般为 `Asia/Shanghai`                 |
| timezone               | 时区信息，国内用户一般为 `GMT+08:00`                     |
| is_daylight            | 含义不明，我这边取值是 `0`                               |
| dst_offset             | 含义不明，我这边取值是 `0`                               |
| PassportDeviceId       | 登录态信息，登录时可以获得                               |
| channel                | 客户端安装渠道，我这边取值是 `MI_APP_STORE`              |

### 请求 Body

| 字段         | 描述                                                  |
| ------------ | ----------------------------------------------------- |
| data         | 请求 payload                                          |
| nonce        | 随机数                                                |
| rc4_hash\_\_ | data 进行了 RC4 加密的话会出现该字段，data 明文的签名 |
| signature    | 请求 Body 的签名                                      |
| ssecurity    | 登录态信息，登录时可以获得                            |

## 请求、响应内容解密

以下代码由 [Xiaomi-cloud-tokens-extractor](https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor/blob/master/token_extractor.py) 改写、裁剪。

> 提示：`ssecurity` 一般为固定值。`nonce` 每次请求均不同。

在完成 HTTPS 抓包后，输入请求 Body 中的 `nonce`、`data` 和 `ssecurity` 后，可以得到请求 payload 的解密结果。将 `data` 替换为响应内容，可以得到响应内容的解密结果。

> 注意：当响应 Header 中 `miot-content-encoding=GZIP` 时，表示响应 Body 的明文内容被 gzip 压缩，因此在解密之后还需要进行一次 gzip 解压。

```python
import base64
import hashlib
import json
import requests
import gzip
from io import BytesIO
from Crypto.Cipher import ARC4

def encrypt_rc4(password, payload):
    r = ARC4.new(base64.b64decode(password))
    r.encrypt(bytes(1024))
    return base64.b64encode(r.encrypt(payload.encode())).decode()

def decrypt_rc4(password, payload):
    r = ARC4.new(base64.b64decode(password))
    r.encrypt(bytes(1024))
    rawPayload = base64.b64decode(payload)
    return r.encrypt(rawPayload)

def get_signed_nonce(ssecurity, nonce):
  hash_object = hashlib.sha256(base64.b64decode(ssecurity) + base64.b64decode(nonce))
  return base64.b64encode(hash_object.digest()).decode('utf-8')

def gzip_unzip(bytes):
  compressedFile = BytesIO()
  compressedFile.write(decrypted_data)
  compressedFile.seek(0)
  return gzip.GzipFile(fileobj=compressedFile, mode='rb').read()

# 待解密的请求 body
nonce = ""
data = ""
ssecurity = ""

# 若解密的是响应 Body，且响应 Header 中有 miot-content-encoding: GZIP，需要设置为 True，否则设置为 False
isGzipped = False

decrypted_data = decrypt_rc4(get_signed_nonce(ssecurity, nonce), payload)
if isGzipped:
  decrypted_data = gzip_unzip(decrypted_data)

# 解密结果
print(decrypted_data.decode("utf-8"))
```

## 请求签名与请求加解密的细节

（待补充）

## 请求构造

以下代码由 [Xiaomi-cloud-tokens-extractor](https://github.com/maxinminax/node-mihome/blob/master/lib/protocol-micloud.js) 改写。支持构造发起无加密的米家 APP 网络请求。必填参数的来源与含义参见上文的“请求格式”。

```javascript
const crypto = require("crypto");
const fetch = require("node-fetch");
const querystring = require("querystring");

class MiHomeApi {
  constructor(props) {
    this.requestTimeout = 5000;
    this.cUserId = props.cUserId;
    this.sSecurity = props.sSecurity;
    this.passportDeviceId = props.passportDeviceId;
    this.serviceToken = props.serviceToken;
    this.userAgent = props.userAgent;
  }

  async request(path, data) {
    const url = this._getApiUrl() + path;
    const params = {
      data: JSON.stringify(data),
    };
    const nonce = this._generateNonce();
    const signedNonce = this._getSignedNonce(this.sSecurity, nonce);
    const signature = this._getSignature(path, signedNonce, nonce, params);
    const body = {
      _nonce: nonce,
      data: params.data,
      signature,
    };

    const res = await fetch(url, {
      method: "POST",
      timeout: this.requestTimeout,
      headers: {
        "x-xiaomi-protocal-flag-cli": "PROTOCAL-HTTP2",
        "User-Agent": this.userAgent,
        "Content-Type": "application/x-www-form-urlencoded",
        Cookie: [
          `cUserId=${this.cUserId}`,
          `yetAnotherServiceToken=${this.serviceToken}`,
          `serviceToken=${this.serviceToken}`,
          "countryCode=CN",
          "locale=zh_CN",
          "timezone_id=Asia/Shanghai",
          "timezone=GMT+08:00",
          "is_daylight=0",
          "dst_offset=0",
          `PassportDeviceId=${this.passportDeviceId}`,
          "channel=MI_APP_STORE",
        ].join("; "),
      },
      body: querystring.stringify(body),
    });

    if (!res.ok) {
      throw new Error(`Request error with status ${res.statusText}`);
    }

    const json = await res.json();
    return json;
  }

  async getHome() {
    const data = await this.request("/v2/homeroom/gethome", {
      fg: true,
      fetch_share: true,
      fetch_share_dev: true,
      limit: 300,
      app_ver: 7,
    });
    return data.result;
  }

  async getDeviceList() {
    const data = await this.request("/v2/home/device_list_page", {
      getVirtualModel: true,
      getHuamiDevices: 1,
      get_split_device: true,
      support_smart_home: true,
    });
    return data.result;
  }

  async invokeRpc(did, method, params) {
    const req = { method, params };
    const data = await this.request(`/home/rpc/${did}`, req);
    return data.result;
  }

  async setMiotSpecProp(did, siid, piid, value) {
    const req = { params: [{ did, siid, piid, value }] };
    const data = await this.request("/miotspec/prop/set", req);
    return data.result;
  }

  async getMiotSpecProp(did, siid, piid) {
    const req = { params: [{ did, siid, piid }] };
    const data = await this.request("/miotspec/prop/get", req);
    return data.result;
  }

  async runScene(scene_id) {
    const req = {
      scene_id,
      trigger_key: "user.click",
    };
    const data = await this.request(
      "/appgateway/miot/appsceneservice/AppSceneService/RunScene",
      req
    );
    return data.result;
  }

  async modifyScene(req) {
    const data = await this.request("/appgateway/miot/appsceneservice/AppSceneService/Edit", req);
    return data.result;
  }

  async getSceneList(home_id) {
    const req = { home_id };
    const data = await this.request("/appgateway/miot/appsceneservice/AppSceneService/GetSceneList", req);
    return data.result;
  }

  _getApiUrl() {
    return "https://api.io.mi.com/app";
  }

  _getSignature(path, _signedNonce, nonce, params) {
    const exps = [];
    exps.push(path);
    exps.push(_signedNonce);
    exps.push(nonce);

    const paramKeys = Object.keys(params);
    paramKeys.sort();
    for (let i = 0, { length } = paramKeys; i < length; i++) {
      const key = paramKeys[i];
      exps.push(`${key}=${params[key]}`);
    }

    return crypto
      .createHmac("sha256", Buffer.from(_signedNonce, "base64"))
      .update(exps.join("&"))
      .digest("base64");
  }

  _generateNonce() {
    const buf = Buffer.allocUnsafe(12);
    buf.write(crypto.randomBytes(8).toString("hex"), 0, "hex");
    buf.writeInt32BE(parseInt(Date.now() / 60000, 10), 8);
    return buf.toString("base64");
  }

  _getSignedNonce(ssecret, nonce) {
    const s = Buffer.from(ssecret, "base64");
    const n = Buffer.from(nonce, "base64");
    return crypto.createHash("sha256").update(s).update(n).digest("base64");
  }
}

const miHomeApi = new MiHomeApi({
  cUserId: "",
  sSecurity: "",
  passportDeviceId: "",
  serviceToken: "",
  userAgent: "",
});

console.log(await miHomeApi.getDeviceList());
```

## 结语

无论是米家设备、米家场景的更多自定义操作，还是将米家设备与米家生态外的硬件、信息联动，米家 APP 都是一个很好的切入点。抓包分析米家 APP（尤其是设备插件控制设备的方式）的网络请求，可以探索、扩展与应用米家设备的诸多能力。

下一篇文章，计划分享一些具体的应用场景：

- 通过米家 API 直接控制设备
- 修改米家场景，引入原本仅在设备插件中支持的操作
- 结合云函数、Automate，实现手机与米家场景的联动