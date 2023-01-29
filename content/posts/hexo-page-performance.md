---
title: 秒开的艺术：Hexo 博客首屏耗时优化实践
categories:
  - 技术
tags:
  - 腾讯云前端性能优化大赛
  - Hexo
date: 2021-12-31
---

> 本文章同步发表在 [腾讯云开发者社区](https://cloud.tencent.com/developer/article/1927584)

## 前言

Hexo 是一款基于 Node.js 的静态博客生成器。有别于传统的 WordPress、Typecho 等由服务端渲染的动态博客程序，Hexo 可以遍历博客的各个页面，将博客文章等内容渲染到主题（即页面模板）之中，生成全部页面的 HTML 文件及其引用的 CSS、JS 等静态资源。这些静态资源文件常常通过托管到 Pages、托管到对象存储或者自建 Nginx 服务器的方式来对外提供访问。

基于 Hexo 搭建的博客固然免去了服务端重复渲染同一个页面的时间与计算资源开销，但是也将更多的模块和页面逻辑移动到了前端页面之中。不同的博主对于博客的功能需求是各不相同，因此主题的各个可选功能也常常是模块化的，需要引入诸多 JS、CSS、图片和字体等静态资源。Hexo 博客页面及其依赖的静态资源的加载、缓存策略，很大程度上影响着 Hexo 博客的访问体验，以下对其中一些优化方法进行阐述。

## 避免资源加载引起的阻塞

HTML 页面常常通过 `<link rel="stylesheet" href>` 以及 `<script src>` 标签引入 CSS 及 JS 文件，在被引用的资源加载期间，浏览器对后续 HTML 内容的解析和渲染会被阻塞，如果资源在页面的头部引入且加载过于缓慢，则会显著增加白屏时长。

```html
<link rel="stylesheet" href="/css/style/main.css">

<!-- 加载缓慢的 CSS -->
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+SC&display=swap" rel="stylesheet">
```

我的站点最初直接引入了 Google Fonts 提供的中文字体，这需要加载一个比较大的 CSS，显著延迟了页面完成加载的时间。这部分字体样式不是页面展示所必须的，因此可以尝试让浏览器延迟加载该 CSS 样式文件，具体的做法如下：

1. 向 link 标签增加 media 属性，值为 only x（这个值在浏览器的媒体查询中与当前页面不匹配，浏览器仍会加载这个 CSS 文件，但不会去使用它，因此也不会阻塞页面的渲染）
2. 向 link 标签增加 onload 属性，这会在浏览器完成 CSS 的加载后被执行。其中进行两个步骤：(1) 清除掉 onload 回调，避免重复执行; (2) 将 media 属性的值置为 all，这会使得浏览器将这个 CSS 应用到页面中。

```html
<!-- CSS 加载时不会阻塞页面渲染 -->
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+SC&display=swap" rel="stylesheet" media="only x" onload="this.onload=null;this.media='all'">
```

同理，避免 JS 文件的加载对页面渲染的阻塞，也可以优化页面的加载速度。当 script 标签带有 defer 属性或 async 属性时，JS 文件的加载不会造成页面渲染的阻塞。

- defer 属性：浏览器会请求该 JS 文件，但会推迟到文档完成解析后，触发 DOMContentLoaded 事件之前才执行
- async 属性：浏览器并行请求带有 async 属性的 JS 文件，并尽快解析和执行

向 script 标签添加 defer 或 async 属性，要根据 JS 脚本的功能与必要性来确定。比如，用来统计页面访问量的 JS 脚本可以添加 async 属性（不依赖 DOM 结构，也不必立即执行）；用于渲染评论区的 JS 脚本可以添加 defer 属性（可以提前加载，且可以等待直到 DOM 加载完成时才执行）。

## 静态资源版本控制

缓存是提高页面加载速度的一个重点。重复加载已经加载过的静态资源文件，无疑会浪费宝贵的时间与带宽。传统的基于 HTTP 缓存头的缓存策略是通过强制缓存一段时间，以及通过修改时间、ETag 来判断服务器上的文件是否已经被修改。在以下两种情况中，这一套缓存策略的表现不佳：

- 在强制缓存的 max-age 时间内，服务器上的文件发生了变更，但浏览器仍然使用旧的文件（导致静态资源更新不及时，或多个静态资源之间有不一致）
- 本地缓存过期，浏览器重新请求服务器，但服务器上的文件实际上没有发生变化。（需要耗费一次往返的时间才能确定本地缓存的静态资源可以使用）

一种静态资源的版本控制方法是向文件名中添加文件内容的哈希值。比如原文件路径为 `css/style.css`，其哈希值的前8位为 `1234abcd`，那么添加了哈希值的文件路径变为 `css/style.1234abcd.css`。这样做的好处是，当文件内容发生变化时，文件名必定发生变化，反过来说，当浏览器已经缓存了该路径的文件，则可以推断缓存的文件在服务器侧没有发生变化，浏览器可以直接使用缓存的版本而不用进行缓存协商（通过设置比较长的强制缓存 max-age 来实现）。

在 Hexo 博客中要实现这种文件版本控制方法，一方面要在 Hexo 构建时修改静态资源的文件名以及对应的引用路径，另一方面要为带哈希值的静态资源设置一个较长的缓存时间，从而实现有效的缓存。

Hexo 支持通过自定义 JS 脚本（放置在 `scripts/` 目录中）对 Hexo 的功能进行扩展，我们可以通过 `hexo.extend.filter.register("after_generate", callback)` 钩子，在 Hexo 生成全部静态文件后对这些文件进行增删改等处理，来实现上述替换静态文件名的操作。具体的代码实现如下：

```js
const hasha = require("hasha");
const minimatch = require("minimatch");

const stream2buffer = (stream) => {
  return new Promise((resolve, reject) => {
    const _buf = [];
    stream.on("data", (chunk) => _buf.push(chunk));
    stream.on("end", () => resolve(Buffer.concat(_buf)));
    stream.on("error", (err) => reject(err));
  });
};

const readFileAsBuffer = (filePath) => {
  return stream2buffer(hexo.route.get(filePath));
};

const readFileAsString = async (filePath) => {
  const buffer = await readFileAsBuffer(filePath);
  return buffer.toString();
};

const parseFilePath = (filePath) => {
  const parts = filePath.split("/");
  const originalFileName = parts[parts.length - 1];

  const dotPosition = originalFileName.lastIndexOf(".");

  const dirname = parts.slice(0, parts.length - 1).join("/");
  const basename =
    dotPosition === -1
      ? originalFileName
      : originalFileName.substring(0, dotPosition);
  const extension =
    dotPosition === -1 ? "" : originalFileName.substring(dotPosition);

  return [dirname, basename, extension];
};

const genFilePath = (dirname, basename, extension) => {
  let dirPrefix = "";
  if (dirname) {
    dirPrefix += dirname + "/";
  }

  if (extension && !extension.startsWith(".")) {
    extension = "." + extension;
  }

  return dirPrefix + basename + extension;
};

const getRevisionedFilePath = (filePath, revision) => {
  const [dirname, basename, extension] = parseFilePath(filePath);
  return genFilePath(dirname, `${basename}.${revision}`, extension);
};

const revisioned = (filePath) => {
  return getRevisionedFilePath(filePath, `!!revision:${filePath}!!`);
};

hexo.extend.helper.register("revisioned", revisioned);

const calcFileHash = async (filePath) => {
  const buffer = await stream2buffer(hexo.route.get(filePath));
  return hasha(buffer, { algorithm: "sha1" }).substring(0, 8);
};

const replaceRevisionPlaceholder = async () => {
  const options = hexo.config.new_revision || {};
  const include = options.include || [];
  const enable = !!options.enable || false;

  if (!enable) {
    return false;
  }

  const hashPromiseMap = {};
  const hashMap = {};
  const doHash = (filePath) =>
    calcFileHash(filePath).then((hash) => {
      hashMap[filePath] = hash;
    });

  await Promise.all(
    hexo.route.list().map(async (path) => {
      const [, , extension] = parseFilePath(path);
      if (![".css", ".js", ".html"].includes(extension)) {
        return;
      }

      let fileContent = await readFileAsString(path);

      const regexp = /\.!!revision:([^\)]+?)!!/g;
      const matchResult = [...fileContent.matchAll(regexp)];
      if (matchResult.length) {
        const hashTaskList = [];

        // 异步获取文件 hash
        matchResult.forEach((group) => {
          const filePath = group[1];
          if (!(filePath in hashPromiseMap)) {
            hashPromiseMap[filePath] = doHash(filePath);
          }
          hashTaskList.push(hashPromiseMap[filePath]);
        });

        // 等待全部 hash 完成
        await Promise.all(hashTaskList);

        // 替换 placeholder
        fileContent = fileContent.replace(regexp, function (match, filePath) {
          if (!(filePath in hashMap)) {
            throw new Error("file hash not computed");
          }
          return "." + hashMap[filePath];
        });

        hexo.route.set(path, fileContent);
      }
    })
  );

  await Promise.all(
    hexo.route.list().map(async (path) => {
      for (let i = 0, len = include.length; i < len; i++) {
        if (minimatch(path, include[i])) {
          return doHash(path);
        }
      }
    })
  );

  await Promise.all(
    Object.keys(hashMap).map(async (filePath) => {
      hexo.route.set(
        getRevisionedFilePath(filePath, hashMap[filePath]),
        await readFileAsBuffer(filePath)
      );
      hexo.route.remove(filePath);
    })
  );
};

hexo.extend.filter.register("after_generate", replaceRevisionPlaceholder);
```

上述示例代码会注册两个钩子：一个是 revisioned 工具函数，另一个是 after_generate 钩子函数。

当 Hexo 模板代码向 revisioned 函数传入一个文件路径（如 `css/style.css`）时，该函数会返回一个包含“文件版本号占位符”（下称为“占位符”）的文件路径。（如 `css/style.占位符.css`，占位符的格式不重要，在后续步骤中能重新识别出来即可）

另一个 after_generate 钩子函数会在 Hexo 构建输出静态文件后执行，它会遍历 Hexo 构建出来的 HTML 等文件，找到其中的“占位符”，并找到对应引用的静态资源文件，计算其版本号，并将占位符替换为版本号。涉及到版本号的文件会同时重命名为带版本号的文件名。

示例代码的实现并不会自动识别哪些文件需要附加版本号，需要使用者自行编辑主题模板代码，将 CSS、JS 等静态资源文件的路径用 revisioned 工具函数进行包裹，从而标志出需要进行版本管理的文件。

**使用示例一**
修改前：`<%- css('css/style.css') %>`
修改后：`<%- css(revisioned('css/style.css')) %>`

**使用示例二**
修改前：`<link href="<%= url_for('css/style/fonts.css') %>" rel="stylesheet">`
修改后：`<link href="<%= url_for(revisioned('css/style/fonts.css')) %>" rel="stylesheet">`

## 基于 IntersectionObserver 的按需加载

Hexo 博客中一些进行内容渲染的 JS 脚本不是在页面加载时必须立即执行的（比如用于渲染评论区的 JS），除了通过上述方法避免阻塞页面渲染以外，也可以在访客即将看到它之前才开始加载，即按需加载。这需要用到 IntersectionObserver API。

在调用 IntersectionObserver API 之前首先要处理一下兼容性问题，避免浏览器不支持 IntersectionObserver API 导致页面内容不显示。然后创建 IntersectionObserver 监听元素出现在视口中的事件。当元素被访客看到时，才进行对应 JS 的加载、执行。下面是代码的实现：

```js
function loadComment() {
  // 插入 script 标签
}

if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver(function (entries) {
    // 浏览器视口与监听的元素有交集时会触发该回调
    if (entries[0].isIntersecting) {
      // 触发 JS 加载
      loadComment();
      // 取消监听，避免重复触发这个回调
      observer.disconnect();
    }
  }, {
    // 回调触发的阈值，这里是 10% 的部分出现在屏幕中时会触发以上的回调
    threshold: [0.1],
  });
  observer.observe(document.getElementById('comment'));
} else {
  // 浏览器不支持 IntersectionObserver，立即触发 JS 加载
  loadComment();
}
```

## 字体裁剪

前面提到我的博客通过 Google Fonts 引入了字体，具体引入的是中文字体 Noto Serif SC（思源宋体）用于标题字体的展示。这里要先说明一下 Google Fonts 对于中文等大字符集的在线字体的提供方式。如果我们通过完整的字体文件向访客分发中文字体是很不现实的，因为一个完整的中文字体包括上千甚至上万个字符，也就是说字体文件的尺寸起码是 MB 级别的，一个字体文件完整下载下来的耗时会很长很长。但是当浏览器支持 `font-family` 的 `unicode-range` 配置后，这个问题就有了转机。

`unicode-range` 的引入使得我们可以指示浏览器只对特定字符使用特定的字体。比如，以下样式指示浏览器：MyLogo 这个 font-family 只对“电”（U+7535）、“脑”（U+8111）、“星”（U+661F）、“人”（U+4EBA）四个字生效。Google Fonts 将字体切分为多个文件，浏览器在渲染页面时按需下载对应的字体文件，而不是将全部字体文件都下载下来。

```css
@font-face {
  font-family: 'Noto Serif SC';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url("./font/logo.woff2") format("woff2");
  unicode-range: U+7535,U+8111,U+661F,U+4EBA;
}

```

很不巧的是 Google Fonts 提供的字体文件里面，我的首页标题的四个大字刚好就分别分布在四个字体文件上。所以有没有办法把它们合在一起？有的有的，上代码：

```js
const fontCarrier = require('font-carrier');
const transFont = fontCarrier.transfer('./NotoSerifSC-Regular.otf');
transFont.min('电脑星人');
transFont.output({
  path: './logo'
});
```

这里用到了 font-carrier 库。我们可以只将页面需要用到的文字从完整的字体文件中裁剪出来，生成字体的子集（subset），从而优化字体的加载和展示体验。（目前只在博客的页面大标题上面用了，暂时没有拉取全部文章标题来生成文章页标题的字体文件）


## 预载下一个页面

最后讲一个有点“取巧”的方法。前面的优化手段针对的是单次页面访问的优化，但访客访问一个站点往往是一个连续的过程，也就是说一位访客进入首页后，如果他对这个网站的内容感兴趣，很有可能通过页面上的超链接继续访问网站的内页。前面已经对 CSS、JS 等静态资源通过缓存优化了加载速度，那么 Hexo 博客的 HTML 静态文件加载是否也有优化的空间？这个问题的回答是肯定的。

这里用到的是 quicklink（https://github.com/GoogleChromeLabs/quicklink），它的实现原理如下：

- 通过 IntersectionObserver 监听出现在浏览器视口中的 `<a>` 标签
- 等待浏览器空闲（通过 requestIdleCallback 注册回调）
- 向页面插入 `<link rel="prefetch" href="a标签指向的 URL">`（这会指示浏览器请求该 URL，从而缓存 URL 指向的资源）

这样，在访客点击超链接跳转到博客的内页之前，这个页面的 HTML、CSS 和 JS 文件应该都已经在浏览器的缓存里面了，页面跳转时的网络请求时间开销被极大降低，从而进一步加快了下一个页面的加载速度。

## 写在最后

一些老生常谈的优化方法，比如接入 CDN，配置 HTTP 缓存头之类的，这里就不多赘述了。这次比赛我个人认为是学习第一，比赛第二，各自起点不同，优化的手段，优化的上限，以及最后优化的幅度都不尽相同。中间优化过程中踩了不少坑，查了不少资料，看着前端性能监控控制台起起落落的数据点排查、思考进一步优化的方法，最后出来的效果我还是比较满意的，甚至起先也没有预料到能达到这个优化的幅度（数字到了一定范围也有点看访客的网络环境和浏览器性能）。

踩过一个小坑是 Aegis SDK 最好在 head 标签就引入并初始化，如果太晚初始化的话首屏时间点的判断会有点问题（比如把后续懒加载的内容当作首屏时间点之类的…首屏直接飙到 4000ms）。Aegis SDK 本身很小，CDN 也很给力，不用太担心早早引入会影响页面的加载。
