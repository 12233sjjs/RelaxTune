# cc优化系统

为 iPhone 13 Pro / iOS 16.6.1 / Relaxin v0.5.6 制作的实验性插件。
提供标准 rootless 和 RootHide 两种包。Relaxin 上游明确采用 RootHide 架构，
不要把标准 rootless 包等同于 Relaxin 可直接使用的包。

## 功能

### 0.4.12 保持启动动画阶段节奏

SpringBoard 私有动画仅转换原始时长在 0.12-1.0 秒内的阶段，更短或更长的阶段保留原时长和延迟。符合范围的时长与延迟使用相同加速倍率，避免把不同长度的启动阶段统一压到 0.12 秒。UIKit 和 SpringBoard 动画保留调用方曲线及 spring 参数，SpringBoard 转场沿用系统 timing function。等级 2 会明显缩短较短动画；此更改保持各阶段的相对节奏，没有设备帧时间测量，不能保证消除实机卡顿。

### 0.4.10 取消插件自身的外部黑名单排除

插件已被注入 App 后，不再读取 RootHide 的黑名单，也不再按固定游戏 Bundle ID 直接退出。
动画、等待网络恢复和 TCP 模块仍按插件各自开关工作；“动画屏蔽名单”仍是独立的手动设置。
这不改变 Relaxin/RootHide 的启动注入规则：如果黑名单让系统完全不加载插件，
仅安装此 deb 无法使 App 进程内的钩子生效，需要先允许该 App 的插件注入。

### 0.4.9 衔接计时与文件夹排除

主动画加速时，同步缩短受控转场的启动延迟，避免只缩短动画时长后留下原等待间隔。
嵌套动画不再重复覆盖曲线或追加从当前状态开始的选项，保留调用方原有阶段关系。
文件夹开合的中央、图标、内外层淡入淡出设置及专用动画入口跳过加速和曲线替换，使用系统动画。
从文件夹启动 App 的普通转场继续受主动画设置控制。独立 120 Hz 请求、唤醒及解锁开关不变。
这些更改处理代码中可确认的计时不一致，不能替代真机帧时间测量；没有 iOS 16.6.1 实机结果。
接口来源和验证边界见 [衔接与文件夹参考](references/animation-0.4.9.md)。

### 0.4.7 独立动画加速

主动画、锁屏唤醒、锁屏解锁分别设置 `0.0–10.0` 的加速等级，步长 `0.1`。
`0` 保持原速度，数值越大越快，`10` 对应最高 `10×` 播放速度；实际速度系数为 `1 + 0.9 × 等级`。
取消原先额外的 `0.8` 时长系数，UIKit 和 SpringBoard 共用同一方向的换算。
主动画保留平滑的非弹簧收尾；唤醒和解锁各有独立开关，默认关闭、等级默认 `0`。
新等级不读取旧版“动画时长比例”，升级后需重新设置。锁屏切换不会写入这些设置。
锁屏解锁加速只调整认证后的动画、壁纸及松手后的完成转场，不缩短 Face ID 或密码校验。
私有接口会先检查运行时签名，不匹配则保持系统行为。没有 iOS 16.6.1 实机结果。
实现依据与覆盖边界见 [动画参考](references/animation-0.4.7.md)。

### 0.4.8 删除全部低电量管理和温控模块

已删除“王者荣耀前台停用低电量”“锁屏省电”“禁用口袋高温”“锁定阳光暴晒”及对应实现。
不再监听前台游戏或锁屏事件来切换低电量，不再载入电源管理私有框架，也不处理旧版低电量恢复标记。
旧偏好值不再读取，升级保持当前低电量状态；需要改变时请在控制中心手动选择。
系统自身温控和低电量模式仍由 iOS 管理。三个动画加速等级及独立 120 Hz 设置保持不变。

### 0.4.2 TCP 小包低延迟

新增独立开关，默认关闭，受总开关控制。启用后，在已注入 App 通过 `socket()` 新建 IPv4/IPv6 TCP socket 时设置 `TCP_NODELAY`，减少 Nagle 算法对小数据发送的等待；App 后续仍可覆盖此设置。参考 [libuv 的 TCP 实现](https://github.com/libuv/libuv/blob/v1.51.0/src/unix/tcp.c) 的标准 socket 选项用法，不依赖 SuperNetwork 二进制。

只覆盖命中该函数 hook 的连接，不影响 UDP/QUIC、系统网络服务或绕过该入口的网络框架。不提高信号强度、不解除套餐限速、不保证游戏延迟或下载速度改善，也不强制修改所有流量优先级。小包数量增加可能提高耗电。更改开关后完全退出并重开目标 App，以便新连接应用设置；存量连接不被强行重置。未进行 iPhone 实机性能验证。

| 设置 | 实际行为 | 默认 |
| --- | --- | --- |
| 总开关 | 停止本插件的动画调整、网络配置及僵尸进程清理 | 开 |
| 调整动画 | 在受控时长范围内加速 UIKit 和 SpringBoard 动画，保留系统曲线与 spring 参数 | 开 |
| 动画加速等级 | 0.0–10.0，步长 0.1；0 为原速，10 最快 | 0 |
| 锁屏唤醒加速 | 独立加速按键/轻点/抬起唤醒动画，等级 0.0–10.0 | 关，等级 0 |
| 锁屏解锁加速 | 独立加速解锁壁纸与完成转场，等级 0.0–10.0 | 关，等级 0 |
| 系统动画120Hz优先 | 在支持 120 Hz 的设备上，为 SpringBoard 显示链接请求 120 Hz | 开 |
| 等待网络恢复 | 新建的默认/临时 URLSession 配置启用 waitsForConnectivity | 开 |

UIKit 动画仅调整原始时长 0.12–1.0 秒的上述动画及其配套启动延迟，不改变长时间进度动画或所有属性动画。
桌面文件夹开合恢复系统原始速度和曲线，文件夹内启动 App 的普通转场不在排除范围。
主动画等级 0 保留原时长和系统曲线；锁屏两项等级 0 或关闭时保持其原始动画。
系统开启“减弱动态效果”时不加速动画。更改倍率后，部分 SpringBoard 设置可能需重新载入界面或重新 SpringBoard 才生效。

120 Hz 选项仅作用于 SpringBoard 的 CADisplayLink 请求，不改变游戏的渲染循环或解锁游戏帧率档位。
关闭该选项或系统低电量模式开启时恢复调用方原始请求；它与三个动画加速等级独立。
按用户要求，插件不再根据严重发热状态主动撤销 120 Hz 请求，也不监听热状态通知。
系统仍可按温度、功耗和显示策略降低实际刷新率，不能保证始终输出 120 FPS。
本项目不包含 CPU/GPU 锁频，不把 3240/1380 MHz 的工具读数当成可写频率档位。

网络模块不修改 TCP、DNS、基带、Wi-Fi 驱动或发射功率，不提高信号，不承诺降低延迟。
它只影响应用采用的新 URLSession 配置，不影响已有会话、直接 socket 或应用自有网络栈。
应用显式设置 waitsForConnectivity 时仍以应用设置为准。该选项只处理建连前等待，
不能恢复已经中断的连接；不会自动重发 POST、支付、上传等请求。
关闭模块后，已有会话配置仍需重启应用才恢复。
如高延迟和断流来自信号、路由器、运营商或代理，该插件无法修复根因。

插件不再因锁屏、充电、进入或退出游戏而开启/关闭低电量模式，也不执行升级恢复写入。
手动低电量模式仍由系统管理，可能影响显示刷新率。升级后可在控制中心确认所需状态。

0.1.6 的固定游戏排除和 0.1.7 的 RootHide 名单自查已在 0.4.10 取消，
当前主插件、TCP 和刷新率模块不再依据外部黑名单跳过初始化。音效模块仍不打包。
插件设置里的“动画屏蔽名单”仅关闭对应 App 进程内的动画调整，不关闭网络模块，
也不控制 SpringBoard 进程负责的 App 开合转场。
插件不会修改 Relaxin/RootHide 的设备黑名单或注入器，不提供检测伪装。
RootHide 若在启动阶段禁止注入，插件代码就无法执行；取消插件自查不能绕过这一限制。
升级或调整注入设置后需完全退出并重新打开目标 App。未进行 iPhone 实机验证。

用户提供的 `system_tweaks(1).sh` 原样保存在 `references/system_tweaks.original.sh`，
原数值已加入安装包的 `Library/ccSystem/system_tweaks.sh` 手动模块。参数审查见 `references/system-tweaks-review.md`。
模块不在安装、启动或进入游戏时自动执行，不需要固定 `/var/jb` 前缀。
在越狱终端取得 root 权限后，通过包管理器文件列表定位脚本：

```sh
script="$(dpkg-query -L com.12233sjjs.relaxtune | sed -n '\|/Library/ccSystem/system_tweaks.sh$|p' | head -n 1)"
sh "$script" apply
# 恢复本模块修改前的数值：
sh "$script" restore
```

支持原脚本六个写入值，跳过不存在、无法读取或非整数的键；写入失败时尝试恢复已经修改的值。
备份保存在 `/var/root/Library/Preferences/ccSystem/kernel-state`，重复执行不会覆盖基线。
恢复时保留其他工具后来更改的值；恢复失败则保留剩余备份。卸载插件前先执行 restore。
这些内核参数没有在目标机验证，其中 86400000 ms 是 24 小时的持续内存压力处理延迟，
不能保证改善帧率或续航，不建议将它作为常规游戏优化。重启后也不自动重放参数。

音效不是杜比，也不是所有 App 音频的全局处理。只覆盖装载该插件且采用 RemoteIO 输出回调的应用，
支持原生小端 float32 或 signed int16、单/双声道、16–192 kHz 的紧凑 PCM。
AVPlayer、AudioQueue、音频单元图连接、系统音效、DRM/卸载渲染路径不保证经过此处理。
不注入音频系统守护进程；跳过系统电话、FaceTime、相机、语音备忘录，跳过 VoiceProcessingIO，
录音和通话类别不启用滤波。AirPlay、蓝牙、不同音频路由仍需逐项实机测试。
固定预设为 100 Hz +2 dB、4000 Hz +1 dB，处理前保留约 3 dB 余量，可能比原声小。
单进程最多包装 64 次回调注册，超出后保持应用原始音频，不尝试强制处理。
默认关闭；未启用时不安装音频钩子或音频路由监听，也不初始化音频会话。
首次开启后只处理新注册的兼容回调，已在播放的 App 可能需重启才能启用。
关闭后不再包装新回调；已注册包装仍透传原始音频，重启应用可清除包装。

插件已无低电量写入或温控覆盖代码，尚无真机续航收益测量。

## 安装

从本仓库 Releases 下载，不要同时安装两个格式。

- 标准 rootless：文件名含 `iphoneos-arm64`，安装路径为 `/var/jb`。
- Relaxin / RootHide：文件名含 `iphoneos-arm64e`，按包管理器支持情况安装。
  这里的包架构名称不能用来判断手机 CPU 架构。
- 依赖 PreferenceLoader 和兼容的插件注入环境。
- 安装后重新载入 SpringBoard，在“设置 → cc优化系统”调整。
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

GitHub Actions 自动检查动画倍率边界、滤波响应/声道独立/非有限数恢复及包内无电源写入/温控接口，
并编译和检查动态库与设置面板。输出附有提交号、构建信息和 SHA-256。
首版以 prerelease 发布，实机验证尚未完成。

## 实机验收

1. 确认两个格式分别由对应环境加载，设置面板、总开关和单项开关有效。
2. 检查 0、0.1、0.5、2、10 级动画，开合 App/文件夹/应用内导航；三个等级分别修改并验证互不影响。
   文件夹开合在各等级应保持原速；对比有阶段延迟的 App 转场，观察是否仍有明显停顿。
   分别验证按键/轻点/抬起唤醒、解锁手势中途取消及完成、关闭开关、减弱动态效果、连续锁屏解锁。
3. 分别手动开启/关闭低电量模式，验证进入/退出王者荣耀、锁屏、解锁及切换插件设置不改变该状态。
   充电时系统自身可能关闭低电量模式；这由 iOS 管理。
4. 同一地点、同一网络分别禁用/启用插件，记录延迟分布、断流次数；
   断网后观察支持的 URLSession 请求能否等待恢复，不把 DNS/路由器问题归功于插件。
5. 相同亮度、信号和使用负载下比较电量变化，至少区分待机与使用阶段。
6. 兼容的 RemoteIO 测试播放器分别验证 float32/int16、单/双声道、44.1/48 kHz，
   检查音乐、通知、录音、电话、蓝牙切换，确认无爆音、回音或麦克风变化。

## 开源调研与来源

- [Relaxin](https://github.com/owngoal-dev/Relaxin)：确认 RootHide 架构及支持系统。
- [RootHide Theos](https://github.com/roothide/theos)：使用其构建与打包方案。
- [Relaxin blacklist lookup](https://github.com/owngoal-dev/Relaxin/blob/f44e0acfef4453989381736e0c86b9c14e7ea045/Vendor/Dopamine/BaseBin/libjailbreak/src/roothider/blacklist.m)：核对 RootHideConfig.plist 的路径及 appconfig 布尔值语义。
- [Speedster](https://github.com/Hoangdus/Speedster)：参考其动画挂钩位置；未复制其偏好设置或固定响应值。
- [Powercuff](https://github.com/rpetrich/Powercuff)：调研低电量/温控机制；未采用温控模拟或复制代码。
- [Theos LowPowerMode headers](https://github.com/theos/headers/blob/master/LowPowerMode/_PMLowPowerMode.h)：核对低电量模式接口及异步完成回调。
- [Immortalizer](https://github.com/sergealagon/Immortalizer)：核对 SpringBoard 前台变化挂钩，未复用其后台保活实现。
- [EQE](https://github.com/rweichler/EQE)：上游说明当前源码不公开，未打包其二进制或使用其代码。
- [Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/)：peaking EQ 双二阶滤波器公式。
- [Apple waitsForConnectivity](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/waitsforconnectivity)：网络等待机制边界。
- [Apple RemoteIO](https://developer.apple.com/documentation/audiotoolbox/kaudiounitsubtype_remoteio)：应用侧输入/输出音频单元。

本项目源码采用 GPL-3.0-only。工具链和系统框架适用各自许可。
