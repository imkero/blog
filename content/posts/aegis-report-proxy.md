---
title: 利用 API 网关解决前端性能监控上报被拦截的问题
categories:
  - 技术
tags:
  - 前端
  - 前端性能监控
  - API 网关
  - Aegis
excerpt: 本文介绍一种通过 API 网关转发前端性能监控的上报请求，以避免上报被浏览器扩展程序拦截的方法。
date: 2022-02-03
---

## 背景

博客接入了腾讯云的 [前端性能监控](https://cloud.tencent.com/product/rum) 以后，我发现通过自己电脑访问博客始终没有被记录。通过 F12 排查，发现是 uBlock Origin 扩展程序将相关的上报请求拦截掉了。

当然，如果只是想让自己电脑上的访问可以正常上报，只需要在扩展程序中设置不对当前域名做过滤即可。但如果想要在实际访客的场景下解决这一个问题，则需要改变上报的 URL 以及上报方式以避开这类扩展程序的过滤。本文介绍一种通过 API 网关转发前端性能监控的上报请求，以避免上报被浏览器扩展程序拦截的方法。

（下文会使用前端性能监控所使用的 Aegis SDK 作为前端性能监控的代称）

## 涉及的过滤规则

要解决上报被拦截的问题，首先要理清拦截的规则。在 uBlock Origin 的“记录器”页面可以查看被拦截的请求及其对应的拦截规则，总结如下。

| 上报类型        | 上报途径 | 上报 URL                             | 过滤规则                              |
| --------------- | -------- | ------------------------------------ | ------------------------------------- |
| PV 上报         | XHR GET  | https://aegis.qq.com/collect/pv      | /collect/pv?                          |
| 测速上报        | XHR GET  | https://aegis.qq.com/speed           | \|\|qq.com/speed                      |
| 自定义上报      | XHR GET  | https://aegis.qq.com/collect         | \|\|qq.com/collect?                   |
| Web Vitals 上报 | Ping     | https://aegis.qq.com/speed/webvitals | \|\|qq.com/speed 或 $ping,third-party |

![uBlock Origin 的记录器中显示被拦截的上报请求](https://imkero-static-1255707222.file.myqcloud.com/posts/aegis-report-proxy/ublock-origin-recorder.png)

## 绕过过滤规则

以上过滤规则可以分为两类：Ping 请求拦截以及请求 URL 过滤拦截。通过配置 Aegis SDK 的初始化参数，可以对发出的上报请求进行修改，以避免在请求实际发出之前被扩展程序拦截。

### Ping 请求过滤

查阅 [上述过滤规则的语法文档](https://kb.adguard.com/en/general/how-to-create-your-own-ad-filters#ping-modifier) 对应的解释如下。

> **`$ping,third-party`**
>
> `$ping`: The rule corresponds to requests caused by either navigator.sendBeacon() or the ping attribute on links.
>
> `$third-party`: A restriction of third-party and own requests. A third-party request is a request from a different domain. For example, a request to `example.org`, from `domain.com` is a third-party request.

即通过 `navigator.sendBeacon` 方法或 `<a ping>` 标签发出的向第三方域名的请求会被拦截。

在前端性能监控中，这个途径被用于上报 Web Vitals 性能数据。通过 Aegis 的 `onBeforeRequest` 钩子函数可以侦听到这一上报请求：

```js
const options = {
  id: 'AEGIS_ID',
  onBeforeRequest(log) {
    if (log.type === 'vitals') {
      console.log('before aegis report vitals', log);
    }
    return log;
  }
};

new Aegis(options);
```

其中 `log` 对象有一个 `sendBeacon` 属性，当其值为 `true` 时，该上报会通过 `navigator.sendBeacon` 发出，否则会通过 XHR 方式发出。

```json
{
  "url": "上报 URL",
  "type": "vitals",
  "log": {
    "FCP": 246.7999997138977,
    "LCP": 490.199,
    "FID": 0.5,
    "CLS": 0
  },
  "sendBeacon": true
}
```

以下代码令 Aegis 通过 XHR 方式上报 Web Vitals 性能数据，从而避开 `$ping,third-party` 过滤规则。

```js
const options = {
  id: 'AEGIS_ID',
  onBeforeRequest(log) {
    if (log.type === 'vitals') {
      log.sendBeacon = false;
    }
    return log;
  }
};

new Aegis(options);
```

### URL 过滤

以下三个 URL 过滤规则对大部分的 Aegis SDK 上报请求进行了过滤。

- `||qq.com/collect?`
- `||qq.com/speed`
- `/collect/pv?`

可以发现前两个是针对 Aegis SDK 的上报域名 `aegis.qq.com` 进行过滤，而后一个则是针对 PV 上报这一上报类型的请求路径 `/collect/pv` 进行了过滤。显然，如果可以改变上报请求的 Host 及请求路径，则可以避开这部分过滤规则。

假设我们实现了一个接入层 `https://example-forwarder.com/`，可以将上报请求转发至 `https://aegis.qq.com/`，具体的转发规则如下（上方的优先级较高）。

- `https://aegis.qq.com/collect/pv` -> `https://example-forwarder.com/collecting/pv`
- `https://aegis.qq.com/(.*)` -> `https://example-forwarder.com/$1`

对应的 Aegis 配置如下。其中 `hostUrl` 影响全部的上报请求，`pvUrl` 影响 PV 上报的上报请求。

```js
const options = {
  id: 'AEGIS_ID',
  hostUrl: '//example-forwarder.com',
  pvUrl: '//example-forwarder.com/collecting/pv',
};

new Aegis(options);
```

## 通过 API 网关转发上报请求

### 请求转发对上报的影响

由于前端性能监控会根据请求的 IP 记录访客所在的地区、运营商等信息，因此在请求转发时，需要还原上报 IP 为访客的原始 IP，否则实际记录的始终是进行转发的 `example-forwarder.com` 的服务器 IP，影响性能监控数据的准确性。

一个好消息是，`aegis.qq.com` 支持通过 `X-Forwarded-For` HTTP 请求头指定上报信息的真实 IP。

### 为什么选择 API 网关

1. API 网关本身即实现了请求转发、响应透传的功能，不需要自行开发并部署支持转发功能的业务服务器。
2. API 网关转发请求时，会自动设置 `X-Forwarded-For` 及 `X-Real-IP` 请求头，可以满足还原上报原始 IP 的需求。[参考文档](https://cloud.tencent.com/document/product/628/50421#.E5.90.8E.E7.AB.AF.E5.AF.B9.E6.8E.A5.E5.85.AC.E7.BD.91-url.2Fip-.E5.92.8C.E5.AF.B9.E6.8E.A5-vpc-.E5.86.85.E8.B5.84.E6.BA.90.E7.9A.84.E7.BB.93.E6.9E.84.E4.BD.93) 

### 创建并配置 API 网关

> 以下按照上文描述的方案给出一个参考配置，请按照实际情况在控制台进行配置。

1. 创建服务

   ![API 网关 - 创建服务](https://imkero-static-1255707222.file.myqcloud.com/posts/aegis-report-proxy/api-gateway-create-service.png)

2. 创建 API

  <table>
    <tr>
      <td><img src="https://imkero-static-1255707222.file.myqcloud.com/posts/aegis-report-proxy/api-gateway-api-1.png"></td>
      <td><img src="https://imkero-static-1255707222.file.myqcloud.com/posts/aegis-report-proxy/api-gateway-api-2.png"></td>
    </tr>
  </table>


## 配置 Aegis

> 以下按照上文描述的方案给出一个参考配置，请按照实际情况填写 Aegis SDK 的初始化配置。

```js
const options = {
  id: 'AEGIS_ID',
  hostUrl: '//example-forwarder.com',
  pvUrl: '//example-forwarder.com/collecting/pv',
  onBeforeRequest(log) {
    if (log.type === 'vitals') {
      log.sendBeacon = false;
    }
    return log;
  }
};

new Aegis(options);
```

## 注意费用

Aegis 在单个页面中会发出多个上报请求，如果对全部访客的上报均使用 API 网关进行转发的话可能会造成较高的 API 网关请求数费用（详见 [API 网关计费概述](https://cloud.tencent.com/document/product/628/48792)），建议只在常规上报途径不可用时才使用上述方案。
