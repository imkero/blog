---
title: 关于
date: 2023-02-26T18:24:00+08:00
---

## 关于博主

- 电脑星人 <span class="secondary" title="also known as">a.k.a</span> Kero
- 技术领域：前端开发 <span class="secondary mh-1">/</span> 物联网

## 关于博客

- 静态页面通过 <a href="https://gohugo.io/" target="_blank">Hugo</a> 构建
- 页面主题基于 <a href="https://github.com/Masellum/hugo-theme-nostyleplease" target="_blank">nostyleplease</a> （有修改）
- 评论系统基于 <a href="https://artalk.js.org/" target="_blank">Artalk</a>，运行于 <a href="https://cloud.tencent.com/product/scf" target="_blank">腾讯云 SCF</a>
- 本站文章采用 <a href="https://creativecommons.org/licenses/by-nc/4.0/deed.zh" target="_blank">知识共享 (Creative Commons) 署名—非商业性使用 4.0 公共许可协议 (CC BY-NC 4.0)</a> 进行许可（文章页中另行声明的，以文章页中的描述为准）

> 让此刻不会老。

## 访客统计

- [访客统计](https://service-ngoos1nm-1255707222.gz.apigw.tencentcs.com/share/M0TKuUnd/kero-blog) 基于 [umami](https://github.com/umami-software/umami)
- PV：<span id="pv-text">-</span>
- UV：<span id="uv-text">-</span>

<script>
(function() {
  if (!window.fetch) return;
  fetch('https://service-ngoos1nm-1255707222.gz.apigw.tencentcs.com/public-stats/kero-blog')
    .then((response) => {
      return response.json();
    })
    .then((res) => {
      if (res.code !== 0) return Promise.reject(new Error('error code = ' + res.code));
      document.getElementById('pv-text').innerText = String(res.data.pageviews.value);
      document.getElementById('uv-text').innerText = String(res.data.uniques.value);
    })
    .catch((error) => {
      console.error('[stats] refresh pv fail', error);
    });
})();
</script>
