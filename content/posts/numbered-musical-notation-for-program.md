---
title: 一种简谱的字符串表达方式
categories:
  - 解决方案
tags:
  - 音乐
date: 2021-11-29
updated: 2021-11-30
---

## 背景

试着在 ESP32 开发板上折腾用蜂鸣器播放音乐，简单来说需要将简谱上标记的音符转换成一系列（频率，时长）的序列，然后控制蜂鸣器发出指定频率、指定时长的声音。网上的一些教程在这一个步骤大都直接快进，在说明原理以后直接给出一段算好的音符序列数据。但实际上如果要手动进行这个转换，想必会比较麻烦，因此有了下面这个尝试。

## 定义

每个音符使用音符数字 `[1-7]` 及后缀修饰符（`^`、`.`、`-`、`*`、`/`、`~`）来表示。

在无修饰符的情况下，一个音符数字表示一个四分音符。

结合简谱的调号、拍号，以及歌曲的速度（BPM），可以计算得到音符的频率和时长。

## 音符的频率

参考：https://github.com/lbernstone/Tone32/blob/master/src/pitches.h

## 音符的修饰符

`/`：音符下方的横线，每个使当前音符时长减半
`^`：音符上方圆点，升高一个八度
`.`：音符下方圆点，降低一个八度
`-`：音符右侧横线，延长一个四分音符的时长
`~`：音符上方连音线，当前音符与下一个音符要连贯演奏
`*`：音符右下附点，一个附点延长原有时长的 0.5 倍，两个附点延长原有时长的 0.5 + 0.25 倍

## 解析、播放简谱字符串

```c
// 发出指定频率的声音
void instrument_play(int freq);
// 停止
void instrument_stop();
// 延时（延时期间声音不停止）
void delay(int ms);

// music 乐谱字符串
// bpm 每分钟节拍数
// baseTone 调号 1=X
// divPerBeat 几分音符为一拍
static void play_music(const char *music, double bpm, char baseTone, int divPerBeat)
{
    // 乐谱字符串读取偏移
    int offset = 0;

    // 一拍的时长
    double beatDuration = 60000 / bpm;

    // 一个四分音符的时长
    int baseNoteDuration = beatDuration * divPerBeat / 4;
    
    while (1) {
        char toneChar = music[offset];
        if (toneChar == '\0') {
            break;
        }

        // 音高，音符数字 1 至 7
        int tone = toneChar - '0';
        // 音符上方或下方的圆点：音高升高或降低 octaveDelta 个八度
        int octaveDelta = 0;
        // 音符下方减时线数量，0=四分音符，1=八分音符，2=十六分音符
        int div = 0;
        // 音符右侧增时线数量
        int multiplier = 1;
        // 音符右侧附点数量
        int dot = 0;
        // 是否有连音线
        bool connect = false;

        // 是否仍有修饰符号需要读取
        bool cont = true;
        while (cont) {
            char nextChar = music[++offset];
            switch (nextChar) {
                case '/': // 减时线
                    div++;
                break;
                case '^': // 音符升高八度
                    octaveDelta++;
                break;
                case '.': // 音符降低八度
                    octaveDelta--;
                break;
                case '-': // 增时线
                    multiplier++;
                break;
                case '~': // 连音线
                    connect = true;
                break;
                case '*': // 附点
                    dot++;
                break;
                case ' ': // 空格忽略
                case '\n': // 换行忽略
                break;
                default:
                    cont = false;
                break;
            }
        }

        double noteDuration = baseNoteDuration;

        // 计算 n 分音符时长
        for (int i = 0; i < div; i++) {
            noteDuration /= 2;
        }

        // 计算附点时长
        double dotDuration = 0;
        int dotDivider = 1;
        for (int i = 0; i < dot; i++) {
            dotDivider *= 2;
            dotDuration += noteDuration / dotDivider;
        }

        noteDuration = noteDuration * multiplier + dotDuration;

        int freq = tone == 0 ? 0 : getNoteFreq(baseTone, tone, 4 + octaveDelta);

        if (connect) {
            // 有连音线，音符之间无间隔
            instrument_play(freq);
            delay((int)(noteDuration));
            instrument_stop();
        } else {
            // 无连音线，音符的 1/4 时长用作间隔
            instrument_play(freq);
            delay((int)(noteDuration * 0.75));
            instrument_stop();
            delay((int)(noteDuration * 0.25));
        }
    }
}
```

## 示例

歌曲是《外婆的澎湖湾》中的一段

```c
play_music(
        "3/.5/.5/.5/.6//.1/*6/.~5/."
        "1/1/6/.6/.5.-"
        "3/3/3/3/4/3/2//~1/*"
        "2//2//2//2//2/3/2-"
        "3/3/3/3//3//4/3/2//~1/*"
        "6/.1/1/6/.5.-"
        "3/3/3/3//3//4/3/2//~1/*"
        "5//.5//.5//.5//.2//~1//7/.1-"
    , 100, 'C', 4);
```

对应的简谱如下。

![](https://imkero-static-1255707222.file.myqcloud.com/posts/numbered-musical-notation-for-program/melody.png)


## 关于我造了个轮子这件事情

刚刚画简谱的时候发现了一个类似的实现，https://aigepu.com/ ，（也就是说我造了个轮子）。这个的实现比较完善，有 [文档](https://www.kancloud.cn/aigepu/xiyou_help/545749)，也可以把符号化的曲谱转换成简谱 [渲染](https://aigepu.com/zhipu) 出来。
