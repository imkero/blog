---
title: 来自 Vinking 的新年游戏
categories:
  - 随笔
tags:
  - CTF
  - 图片隐写
  - LSB
excerpt: 本文介绍一个基于 LSB 图片隐写的谜题及其解法，祝大家兔年大吉🐇。
date: 2023-01-31
---

春节假期期间，笔者在 [开往](https://travellings.cn/) 闲逛的时候偶然看到了 [Vinking](https://vinking.top/) 的 [新年游戏](https://vinking.top/76.html)，觉得很有意思，经过一番努力后终于成功完成解谜，这里简单记录一下中间用到的工具与学到的知识。

## 题目

原文链接：[又一个新年游戏](https://vinking.top/76.html)

题目图片：<https://tudingtu.cn/i/2023/01/28/rce26w.png>

> 信息在这张图片里面，找到加密方式的线索也在图片里面。
>
> 信息被以一种非常经典的加密方法加密在图片里面。
>
> 这种加密方式鲁棒性非常低且不推荐加密 JPG 图片格式，因为 JPG 格式的压缩算法有可能会破坏加密的信息。
>
> 加密方式不是上一年新年游戏的加密方式。
> 最终密码是纯英文字母。
>
> 你或许需要一个十六进制查看器，不用担心，我已经帮你找好啦， [正在部署传送门](https://hexed.it/) 。

<small><i>注：上一年新年游戏（2022年）的加密方式指的是在图片文件的末尾直接追加一个 zip 压缩包</i></small>

## 初步推测

根据题目的描述，初步作出以下猜测：

- 找到加密方式的线索也在图片里面 -> **图片里面藏了提示**
- 这种加密方式鲁棒性非常低且不推荐加密 JPG 图片格式，因为 JPG 格式的压缩算法有可能会破坏加密的信息。 -> **信息被隐藏在图片的像素中**
- 你或许需要一个十六进制查看器 -> **提示不在图片的可见部分，可能在图片末尾或者某个 PNG 数据段中**
- 最终密码是纯英文字母 -> 图片中隐藏的信息可能是**获得最终密码的线索**；或者**需要对图片中隐藏的信息进行加工**，才能得到最终的信息。

在实际动手之前，大胆盲猜是用了图片盲水印或者图片隐写的方式将信息隐藏到了图片之中。比较大可能是简单的图片隐写，如果是盲水印方法，一般经过 JPG 压缩后仍然可能保有水印信息。

另外，猜测题目中的图片可能在网络中可以找到原图，虽然应该和题目关系不大，但还是顺手用识图工具先找到了出处：<https://www.pixiv.net/artworks/95913662>。

## 寻找提示

首先根据题目指引寻找“加密方式的线索”。用十六进制编辑器打开图片文件，可以在文件末尾发现在 PNG 的正常文件尾后面还有一段文本，正是我们所要寻找的提示：

> This image is encrypted in a way called "LSB steganography".

翻译过来就是说：信息是使用 **LSB 隐写**的方式加密到图片里面的。

<small><i>注1：PNG 格式是由 PNG 文件头 + 多个数据段组成的，每个数据段的结构是 <code>4 bytes Length + 4 bytes Type + N bytes Data + 4 bytes CRC</code>。一般最后一个数据段的 Type 是 IEND，Length 为 0，也就是说正常 PNG 文件的结尾部分必定是这十二个字节： <code>00 00 00 00 49 45 4E 44 AE 42 60 82</code> 。</i></small>

<small><i>注2：后来 Vinking 降低了题目难度，在提示中给出了加密时所用的工具，提示中追加的内容如下：Encryption tool: https://github.com/RobinDavid/LSB-Steganography。</i></small>

## 关于 LSB 隐写

所谓 LSB 隐写，用一句话来说就是**像素上的藏头诗**。LSB 指的是最低有效位（Least significant bit），在图片隐写中，指的是将信息写入图片像素的最低有效位。

在 RGB 颜色系统中，每个像素都有红（Red），绿（Green）和蓝（Blue）三个颜色分量，每个分量都可以在 0 ~ 255 之间的整数中取值。每个颜色分量恰可以用 1 个字节，也就是 8 个比特位来表示。

当我们**改变**颜色分量的**最低有效位**时，对实际的**颜色值影响很小**，比如 255 是二进制 0b11111111，而 254 在二进制中是 0b11111110。颜色 `rgb(255,0,0)` 和 `rgb(254,0,0)` 是两种相近的颜色，**人眼很难分辨这两种相近的颜色**。

反之，当我们改变颜色分量的最高有效位（MSB）时，对实际的十进制颜色值影响很大，比如 255 是二进制 0b11111111，而 127 在二进制中是 0b01111111。颜色 `rgb(255,0,0)` 和 `rgb(127,0,0)` 这两种颜色的差异肉眼显然可辨。

利用这一点，我们可以像藏头诗一样，把信息隐藏在颜色分量的最低有效位上。只有知晓这一点的人，才能发现图片中隐藏的信息。而且**嵌入信息前后，图片没有明显变化**。

太长不看版示意图：

![](https://imkero-static-1255707222.file.myqcloud.com/attachments/vinking-new-year-game-2023/lsb-steg.png)


## LSB 隐写的“方言”

显然，在 RGB 颜色系统中，一个像素可以有三个颜色分量，也就是说每个像素可以嵌入 3 比特的数据。若图片的分辨率为 2 * 2，则其中有 4 个像素，也就是可以承载 4 * 3 = 12 比特，也就是 1.5 个字节的数据。图片的分辨率越大，可以嵌入的信息量也越大。

但我们很容易发现一个问题，LSB 隐写没有一种普适的规范来约定**信息写入到图片中的方式**（下文统称为“隐写参数”），所谓的隐写参数包括写入的通道、顺序和位置，具体来说可以分为如下几类：

- **二进制位上的位置**：信息一定是在颜色值的最低位？能否藏在倒数第二位上？
- **像素内的顺序**：连续三个比特是按 RGB 的顺序，还是反过来按 BGR 的顺序写入到同一个像素中？另外地，也可能只有其中一个分量被写入了信息。
- **像素间的顺序**：写入的顺序是先横向再纵向，还是先纵向再横向？甚至更复杂的，比如先奇数列再偶数列？
- **在图片中的位置**：信息是在图片的左上角？右下角？或者是中间？

因此，如果对同一张图片用不同的隐写参数解读其中可能隐藏的 LSB 隐写信息，会有多种解读结果，但往往只有其中一种（即与最初写入信息时相同的那种）能得到有效的信息。在没有更多线索的情况下，我们有两个尝试方向：（1）先进行初步分析，提出一些高可能性的隐写参数，尝试按照这些隐写参数找到图片中隐藏的信息。（2）用蛮力解决问题，遍历尽可能多种隐写参数，观察是否有某种隐写参数的解读结果中包含了某些信息。

## 使用工具辅助分析 LSB 隐写

下面介绍笔者用到的两种 LSB 隐写分析工具，对应前面提到的两个尝试方向，这两个方向最终都能得到预期的结果。

### 图片通道提取工具

前面说到 LSB 隐写是把信息写入到图片的最低有效位上，因此，我们可以对原始图片中的每个颜色分量进行以下处理：

遍历图片中的每个像素，若当前像素的指定颜色分量的最低有效位为 1 ，则映射为白色，反之映射为黑色。

假设原始图片有 RGB 三个颜色分量，如此处理后可以得到三张黑白双色的图片，这三张图片（称为 Bit Planes）仅包含原始图片中指定颜色分量的最低有效位上的信息。观察这三张图片，可能可以发现图片中藏有 LSB 隐写信息的痕迹：包含信息的区域，其像素分布的模式与不包含信息的部分相比，往往有所不同。

实际上我们不需要自行编写这种工具，目前已经有现成的工具实现了这种提取方法：

- [stegsolve](http://www.caesum.com/handbook/Stegsolve.jar)（需要 Java 环境）
- [stegonline](https://stegonline.georgeom.net/)（网页工具）

这里我们用 [stegonline](https://stegonline.georgeom.net/)（网页工具方便一些，不需要装 Java 环境）。

1. 首先将图片末尾的“提示”去掉，使其恢复为正常的 PNG 格式（因为 stegonline 不兼容 PNG 末尾有额外内容的文件）。
2. 然后用 stegonline 打开 PNG 文件。
3. 点击【Browse Bit Planes】
4. 然后点击【<】或【>】箭头按钮翻页，可以发现 Red 0、Green 0 和 Blue 0 的左上角第一行均有一些明显不符合原始图片颜色规律的像素排列。（这个比较凭感觉）

![](https://imkero-static-1255707222.file.myqcloud.com/attachments/vinking-new-year-game-2023/lsb-red-plane-0.png)

由此可以推断，信息的位置是在图片左上角，方向先横向再纵向，但通道顺序还不能确定，有可能是 RGB、BGR 等不同的顺序。但我们已经将可能的隐写参数的种类数量缩小到 6 种（3 的排列数是 6），可以尝试提取这些二进制数据作进一步观察了。

1. 点击【Extract Files/Data】
2. 勾选【R0】【G0】【B0】
3. 【Pixel Order】选择【Row】
4. 【Bit Plane Order】分别尝试【RGB】【BGR】等 R、G、B 三者的可能排列
5. 点击【Go】，观察提取出来的信息。

这里笔者一开始卡在这个位置了，后来 Vinking 提醒道图片中隐藏的信息是中文的。最终在 Bit Plane Order 为 BGR 的结果中发现了有效的信息。

![](https://imkero-static-1255707222.cos.ap-guangzhou.myqcloud.com/attachments/vinking-new-year-game-2023/lsb-bgr-result.png)

1. 点击【Download Extracted Data】
2. 用文本编辑器打开浏览

内容如下：

> 似乎最终答案被加密成了后面这样一段  佛曰：呼俱是諳所侄苦俱智缽故喝僧無怯曳一藝怯寫皤呼罰迦曰

可能是一种密文，需要找到它的密码表来翻译回原文。后续的解密先按下不表，下面介绍另外一种用蛮力解决问题的工具，同样可以得到上述的结果。

### 暴力法工具

对于人类而言，即使在工具的辅助下，要把我们前面提到的 LSB 隐写的各种变体（RGB，BGR 等）全部遍历一遍也是非常费力的。但对于计算机来说，在千万个像素中寻找符合特定模式的字节序列，不过是弹指工夫。

当然，前提是图片中藏有的信息是我们可以识别的。常见的可识别内容包括：文本（连续若干个可见字符），PNG文件（通过文件头或关键字来识别），ZIP文件（通过文件头来识别）等等。

笔者用到的暴力法工具是 zsteg，它可以遍历寻找 PNG 图片中通过隐写方法隐藏的信息，支持 RGB 通道顺序，BGR 通道顺序，xy 方向，yx 方向等不同的隐写模式。

zsteg 是使用 Ruby 编写的工具，使用前需要先安装 Ruby。

1. 安装 zsteg：`gem install zsteg`
2. 尝试解密图片：`zsteg EncryptedImage.png`

再重复前面提到的额外提示，被加密的内容是中文的，而 zsteg 默认情况下不能识别中文字符，需要对其代码进行 [修改](https://github.com/imkero/zsteg/commit/bba93e5013ec845234f43291bab4b45cc3304af6)（代码里面有支持，但是被注释掉了是什么情况？）

```bash
# find zsteg's install location dir
gem env | grep INSTALL

# find checker.rb file
find /usr/local/rvm/gems/ruby-3.1.3/gems -name checker.rb

# edit it
nano /usr/local/rvm/gems/ruby-3.1.3/gems/zsteg-0.2.11/lib/zsteg/checker.rb
```

然后再运行 zsteg，即可得到结果：

```
[?] 131 bytes of extra data after image end (IEND), offset = 0x166de8
extradata:0         .. text: "     This image is encrypted in a way called \"LSB steganography\". Encryption tool: https://github.com/RobinDavid/LSB-Steganography."
imagedata           .. file: VAX-order 68k Blit mpx/mux executable
b1,rgb,msb,xy       .. EճTݱTud5
b1,bgr,lsb,xy       .. 似乎最终答案被加密成了后面这样一段
                    .. 呼俱是諳所侄苦俱智缽故喝僧無怯曳一藝怯寫皤呼罰迦曰vK
b2,r,msb,xy         .. file: shared library
b2,g,lsb,xy         .. text: "5eUUUUUUg?"
b2,g,msb,xy         .. text: "EWUUUUUU"
b2,b,msb,xy         .. text: "/U[]UUUUUU"
...（后续内容略）
```

<small><i>注：可以发现识别出来的中文缺失了“佛曰：”几个字符，但输出结果中同时提示了 zsteg 提取该字符串时的隐写参数 <code>bgr,lsb,xy</code>。对照参数手动操作提取，同样可以得到完整的信息。</i></small>

## 又一个解谜？

图片中隐藏的信息如下：

> 似乎最终答案被加密成了后面这样一段  佛曰：呼俱是諳所侄苦俱智缽故喝僧無怯曳一藝怯寫皤呼罰迦曰

将“佛曰：”这段通过搜索引擎搜索，发现是用了一种叫“与佛论禅”的加密方法。很快地也找到了 [解密工具](https://www.keyfc.net/bbs/tools/tudoucode.aspx)

解密结果是：`Bingo`

回到 Vinking 的新年游戏博文页面，输入 `Bingo`，提交，得到密钥。

<small><i>注：与佛论禅的算法，本质上是使用一个固定的密钥对原文进行 AES 加密，然后进行 base64 编码，最后将 base64 的字符集映射到一些中文字符上。这种算法的实现可以参考 [Kwansy98/yufolunchan](https://github.com/Kwansy98/yufolunchan/blob/master/src/buddhism/BuddhismTools.java)</i></small>

## 写在最后

最终找到答案时，有种豁然开朗的感觉。一个很有意思的题目，感谢 Vinking。最后，祝大家新年快乐，兔年大吉！
