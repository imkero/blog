---
title: 找回消失的 Microsoft Store
categories:
  - 笔记
tags:
  - Windows
  - 'Microsoft Store'
date: 2022-12-14
---

## 写在前面

背景是这样的：预装 Windows 11 的新电脑，进入系统后完全找不到 Microsoft Store。尝试了以下操作，但皆未解决问题：

- 在开始菜单中搜索 Microsoft Store：未搜索到
- 通过 URL Scheme `ms-windows-store://` 打开：提示需要安装应用以打开该 URL
- 运行疑难解答程序“查找并修复 Microsoft Store 应用问题”：无结果，提示“疑难解答未能确定问题”
- 参照网上的一些教程先卸载 Microsoft Store 再重装：无效果，貌似本来就没安装，因此重装的步骤无法完成。（我猜大都是转载 [这个问题](https://answers.microsoft.com/en-us/windows/forum/all/windows-store-missing/6addee3e-1a27-42e0-88e0-a4b3717658bc) 的回答中描述的步骤？）
- 重装系统：通过 Windows 自带的重装系统功能（下载最新的镜像）进行重装，重装后问题依旧。

## 解决方法

TL;DR: (1) 找齐 Microsoft Store 本体及其依赖的安装包文件；(2) 逐个安装包进行安装：先安装依赖，最后安装本体; 完成后可解决此问题。

具体步骤参考 [这篇文章](https://www.winhelponline.com/blog/restore-windows-store-windows-10-uninstall-with-powershell/) 描述的方法二 `Download the Microsoft Store installer (Appx package)`

## 步骤

简单复述我的操作如下：

1. 复制 Microsoft Store 的应用商店页面 URL `https://www.microsoft.com/en-us/p/microsoft-store/9wzdncrfjbmp`（Microsoft Store 本身也是一个可安装的应用，它有自己的应用商店页面）
2. 访问 [https://store.rg-adguard.net/](https://store.rg-adguard.net/) （在该网站输入应用商店页面 URL 后，可以查询到该应用及其依赖的 appx 文件列表及下载地址）
3. 粘贴步骤一中复制的 URL，下拉框选择 `Retail`，点击“√”按钮
4. 跳转到一个文件列表页面，在其中下载五个 appx 文件：`Microsoft.VCLibs.*.Appx`, `Microsoft.UI.Xaml.*.Appx`, `Microsoft.NET.Native.Runtime.*.Appx`, `Microsoft.NET.Native.Framework.*.Appx`, `Microsoft.WindowsStore.*.Msixbundle`。（其中前四个是依赖，最后一个是本体；有多个版本的话挑版本号最大的）
5. 逐个双击安装（Microsoft.UI.Xaml 通过 GUI 安装会失败，可以换用 Powershell 命令行 `Add-AppxPackage -Path <appx文件路径>` 进行安装）
