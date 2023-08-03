---
title: 关于
date: 2023-08-03T15:32:00+08:00
---

## 关于博主

- 电脑星人 <span class="secondary" title="also known as">a.k.a</span> Kero
- 技术领域：前端开发 <span class="secondary mh-1">/</span> 物联网

## 关于博客

- 静态页面通过 <a href="https://gohugo.io/" target="_blank">Hugo</a> 构建
- 页面主题基于 <a href="https://github.com/Masellum/hugo-theme-nostyleplease" target="_blank">nostyleplease</a> （有修改）
- 本站文章采用 <a href="https://creativecommons.org/licenses/by-nc/4.0/deed.zh" target="_blank">知识共享 (Creative Commons) 署名—非商业性使用 4.0 公共许可协议 (CC BY-NC 4.0)</a> 进行许可（文章页中另行声明的，以文章页中的描述为准）

> 让此刻不会老。

## 访客统计

- [访客统计](https://pageview.kero.blog/share/6p0PPEcw/kero-blog) 基于 [umami](https://github.com/umami-software/umami)
- PV：<span id="pv-text">-</span>
- UV：<span id="uv-text">-</span>

<script>
(function() {
  if (!window.fetch) return;
  fetch('https://pageview.kero.blog/api/share/stats/6p0PPEcw')
    .then((response) => {
      return response.json();
    })
    .then((res) => {
      document.getElementById('pv-text').innerText = String(res.pageviews.value);
      document.getElementById('uv-text').innerText = String(res.uniques.value);
    })
    .catch((error) => {
      console.error('[stats] fetch stats fail', error);
    });
})();
</script>
