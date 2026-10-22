# RelaxTune

为 iPhone 13 Pro / iOS 16.6.1 / Relaxin v0.5.6 制作的实验性插件。
提供标准 rootless 和 RootHide 两种包。Relaxin 上游明确采用 RootHide 架构，
不要把标准 rootless 包等同于 Relaxin 可直接使用的包。

## 功能

| 设置 | 实际行为 | 默认 |
| --- | --- | --- |
| 总开关 | 停止本插件的动画、网络配置及均衡器处理，恢复插件接管的低电量状态 | 开 |
| 调整动画 | UIKit 普通视图动画及 SpringBoard 应用开合弹簧响应 | 开 |
| 动画时长比例 | 0.00–10.00，步长 0.01；1.00 原速，0.90 微快，数值越小越快 | 0.90 |
| 等待网络恢复 | 新建的默认/临时 URLSession 配置启用 waitsForConnectivity | 开 |
| 锁屏省电 | 未充电且锁屏时开启系统低电量模式，解锁或充电时恢复 | 开 |
| 播放均衡器 | 兼容 RemoteIO 回调的单/双声道 PCM 播放路径，轻量低频与高频增强 | 关 |

动画仅调整原始时长 0.12–1.0 秒的上述动画，不改变长时间进度动画、交互式手势或所有属性动画。
0 倍时普通动画立即完成；SpringBoard 弹簧响应最小为 0.01 秒，防止零值异常。
系统开启“减弱动态效果”时不加速动画。更改倍率后，部分 SpringBoard 设置可能需重新载入界面或重新 SpringBoard 才生效。

网络模块不修改 TCP、DNS、基带、Wi-Fi 驱动或发射功率，不提高信号，不承诺降低延迟。
它只影响应用采用的新 URLSession 配置，不影响已有会话、直接 socket 或应用自有网络栈。
应用显式设置 waitsForConnectivity 时仍以应用设置为准。该选项只处理建连前等待，
不能恢复已经中断的连接；不会自动重发 POST、支付、上传等请求。
关闭模块后，已有会话配置仍需重启应用才恢复。
如高延迟和断流来自信号、路由器、运营商或代理，该插件无法修复根因。

省电使用系统低电量模式来减少后台活动，不杀后台、不清内存、不禁用系统守护进程、
不模拟过热、不降低系统安全保护。可能影响后台刷新、同步和显示刷新率。
若用户原本已开启低电量模式，插件不在解锁时关闭它。锁屏期间手动关闭低电量模式后，
本次锁屏不再强制开启。卸载前先解锁并关闭插件总开关，确认已恢复所需低电量状态。

音效不是杜比，也不是所有 App 音频的全局处理。只覆盖装载该插件且采用 RemoteIO 输出回调的应用，
支持原生小端 float32 或 signed int16、单/双声道、16–192 kHz 的紧凑 PCM。
AVPlayer、AudioQueue、音频单元图连接、系统音效、DRM/卸载渲染路径不保证经过此处理。
不注入音频系统守护进程；跳过系统电话、FaceTime、相机、语音备忘录，跳过 VoiceProcessingIO，
录音和通话类别不启用滤波。AirPlay、蓝牙、不同音频路由仍需逐项实机测试。
固定预设为 100 Hz +2 dB、4000 Hz +1 dB，处理前保留约 3 dB 余量，可能比原声小。
单进程最多包装 64 次回调注册，超出后保持应用原始音频，不尝试强制处理。
默认关闭；关闭后的已注册包装仍透传原始音频，重启应用可清除包装。

## 安装

从本仓库 Releases 下载，不要同时安装两个格式。

- 标准 rootless：文件名含 `iphoneos-arm64`，安装路径为 `/var/jb`。
- Relaxin / RootHide：文件名含 `iphoneos-arm64e`，按包管理器支持情况安装。
  这里的包架构名称不能用来判断手机 CPU 架构。
- 依赖 PreferenceLoader 和兼容的插件注入环境。
- 安装后重新载入 SpringBoard，在“设置 → RelaxTune”调整。
- 如 Relaxin 要求对目标 App 单独开启注入，需在其管理工具中开启后重启目标 App。

没有连接目标手机进行安装或运行验证。编译通过不等于设备兼容或收益已验证。
出现异常时通过越狱环境禁用本插件并卸载；不要为此反复重启系统服务。
关闭前台 App 或总开关不等于主动恢复该 App 已复制的网络会话配置。

## 构建

依赖 Xcode iPhoneOS SDK、RootHide Theos、ldid、dpkg。
CI 固定 Theos 及其子模块版本，并从 Theos iOS 16.5 SDK 下载经 SHA-256 核对的 Preferences 链接描述，
构建 arm64 / arm64e 通用二进制，两种格式分别打包。手动构建需使用包含 Preferences 的 SDK，
或与 CI 一样将该链接描述放入 `work/frameworks/Preferences.framework/Preferences.tbd`。

```sh
export THEOS=/path/to/roothide/theos
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
```

GitHub Actions 自动检查省电状态决策、动画倍率边界、滤波响应/声道独立/非有限数恢复，
并编译和检查动态库与设置面板。输出附有提交号、构建信息和 SHA-256。
首版以 prerelease 发布，实机验证尚未完成。

## 实机验收

1. 确认两个格式分别由对应环境加载，设置面板、总开关和单项开关有效。
2. 检查 0、0.9、1、10 倍动画，开合 App/文件夹/应用内导航、系统减弱动态效果。
3. 先关低电量模式：锁屏启用，解锁/充电恢复；原本开启时保持开启。
4. 同一地点、同一网络分别禁用/启用插件，记录延迟分布、断流次数；
   断网后观察支持的 URLSession 请求能否等待恢复，不把 DNS/路由器问题归功于插件。
5. 相同亮度、信号和使用负载下比较电量变化，至少区分待机与使用阶段。
6. 兼容的 RemoteIO 测试播放器分别验证 float32/int16、单/双声道、44.1/48 kHz，
   检查音乐、通知、录音、电话、蓝牙切换，确认无爆音、回音或麦克风变化。

## 开源调研与来源

- [Relaxin](https://github.com/owngoal-dev/Relaxin)：确认 RootHide 架构及支持系统。
- [RootHide Theos](https://github.com/roothide/theos)：使用其构建与打包方案。
- [Speedster](https://github.com/Hoangdus/Speedster)：参考其动画挂钩位置；未复制其偏好设置或固定响应值。
- [Powercuff](https://github.com/rpetrich/Powercuff)：调研低电量/温控机制；未采用温控模拟或复制代码。
- [EQE](https://github.com/rweichler/EQE)：上游说明当前源码不公开，未打包其二进制或使用其代码。
- [Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/)：peaking EQ 双二阶滤波器公式。
- [Apple waitsForConnectivity](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/waitsforconnectivity)：网络等待机制边界。
- [Apple RemoteIO](https://developer.apple.com/documentation/audiotoolbox/kaudiounitsubtype_remoteio)：应用侧输入/输出音频单元。

本项目源码采用 GPL-3.0-only。工具链和系统框架适用各自许可。
