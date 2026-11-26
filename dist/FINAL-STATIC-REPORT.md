# RelaxTune 0.5.1 最终 DEB 独立只读审计

## 结论

**PASS_STATIC：在本次明确的静态审计范围内通过，未发现需阻断的归档元数据或补丁字节问题。** 主 Filter 扩大及其他现有功能在原守卫下共同扩大是已授权行为，不按缺陷处理。此结论不等同于 iOS 实机、PAC 执行、AMFI 信任或实际 120Hz 效果通过。

直接读取三份 DEB：独立解析 ar/tar、Mach-O load commands/符号/间接符号表、初始化偏移和函数起点，使用 Capstone 反汇编并按字节重算 CodeDirectory。既有 audit.json/补丁脚本仅用作坐标线索，未导入或执行其实现。输入包审计前后 SHA-256 均一致；未修改产物、既有脚本或仓库，未提交、未上传。

## 1. 输入身份

- 候选：`/var/minis/workspace/refresh-continue/delivery-final/com.12233sjjs.relaxtune_0.5.1_iphoneos-arm64e.deb`；50070 字节；SHA-256 `d9d430c5327ecdffa8e1c821e479a76571ff4cfba9ff686f9f09b9789839b375`。
- 包一：`/var/minis/shared/relaxtune/recovered-originals/com.12233sjjs.relaxtune_0.5_iphoneos-arm64e.deb`；33228 字节；SHA-256 `d5130ca773d45b45ca48e61781b88365a0492b93eec3ce84519d389c348b8403`。
- 包二：`/var/minis/shared/relaxtune/recovered-originals/ProMotion 120Hz-1.0.14-1-iphoneos-arm64e.deb`；19460 字节；SHA-256 `b96bfa462178b034897400cec04cdbd334a27453f8582f6738de0dc6e7c741ff`。

## 2. 21 个原始归档条目的全部指定元数据

原包 control 2 项 + data 19 项 = **21 项**，候选 23 项 = 原 21 项 + 新增 2 项。逐项比较 uid/gid/uname/gname/mode/mtime/type/linkname，全部相等，解析后的条目路径保持一致，无删除或其他新增。另直接解析解压后 512 字节 tar 头并校验头校验和，独立复核八字段值仍为 21/21 相同。tar 头本身经过重编码（USTAR 路径前缀与 GNU 完整路径、目录末尾斜线及八进制数字填充形式有差异），本结论是字段值/条目语义保持，不宣称原始 tar 头逐字相同。原 21 项共同字段全部为 **uid=501、gid=20、uname=root、gname=wheel、linkname=空字符串**。不得把文本 root/wheel 误写成数值 0:0，也不得拿解包后本机 stat 所有权代替归档记录。其余三字段逐项如下；type 5=目录、0=普通文件，mtime 为原始 epoch 秒，表中即原包与最终包共同值。

| 归档 | 原始条目名称 | mode | mtime | type |
|---|---|---:|---:|---:|
| control | `.` | 0755 | 1795180615 | 5 |
| control | `./control` | 0644 | 1795180615 | 0 |
| data | `.` | 0755 | 1795180615 | 5 |
| data | `Library` | 0755 | 1795180615 | 5 |
| data | `Library/MobileSubstrate` | 0755 | 1795180614 | 5 |
| data | `Library/MobileSubstrate/DynamicLibraries` | 0755 | 1795180614 | 5 |
| data | `Library/MobileSubstrate/DynamicLibraries/RelaxTune.dylib` | 0755 | 1795180614 | 0 |
| data | `Library/MobileSubstrate/DynamicLibraries/RelaxTune.plist` | 0644 | 1795180615 | 0 |
| data | `Library/PreferenceBundles` | 0755 | 1795180615 | 5 |
| data | `Library/PreferenceBundles/RelaxTunePrefs.bundle` | 0755 | 1795180613 | 5 |
| data | `Library/PreferenceBundles/RelaxTunePrefs.bundle/Info.plist` | 0644 | 1795180615 | 0 |
| data | `Library/PreferenceBundles/RelaxTunePrefs.bundle/RelaxTunePrefs` | 0755 | 1795180613 | 0 |
| data | `Library/PreferenceBundles/RelaxTunePrefs.bundle/Root.plist` | 0644 | 1795180615 | 0 |
| data | `Library/PreferenceBundles/RelaxTunePrefs.bundle/icon.png` | 0644 | 1795180566 | 0 |
| data | `Library/PreferenceBundles/RelaxTunePrefs.bundle/icon@2x.png` | 0644 | 1795180566 | 0 |
| data | `Library/PreferenceBundles/RelaxTunePrefs.bundle/icon@3x.png` | 0644 | 1795180566 | 0 |
| data | `Library/PreferenceLoader` | 0755 | 1795180566 | 5 |
| data | `Library/PreferenceLoader/Preferences` | 0755 | 1795180566 | 5 |
| data | `Library/PreferenceLoader/Preferences/RelaxTune.plist` | 0644 | 1795180615 | 0 |
| data | `Library/ccSystem` | 0755 | 1795180566 | 5 |
| data | `Library/ccSystem/system_tweaks.sh` | 0644 | 1795180566 | 0 |

外层 ar 的 debian-binary、control.tar.gz、data.tar.lzma 顺序/名称/uid/gid/mode/mtime 与原包一致：uid=0、gid=0、mode=100644、mtime=1795180616；仅压缩 tar 的长度与负载改变，debian-binary 负载仍逐字相同。所有 tar 名称安全且无重复规范路径、链接、PAX 覆盖记录。

新增两文件的八项元数据均完全沿用包二对应条目：uid=0、gid=0、uname=root、gname=root、mtime=1791543034、type=0、linkname=空字符串，dylib mode=0755、plist mode=0644。它们并非原 21 项，按本次规则可接受。

## 3. 原七个无关文件逐字不变

| 文件 | 字节 | 原包与候选共同 SHA-256 |
|---|---:|---|
| `Library/PreferenceBundles/RelaxTunePrefs.bundle/Info.plist` | 276 | `0b418065baba04e8c9f75350adb4ebd91772e5d5bf549b771d983f055efcb5e5` |
| `Library/PreferenceBundles/RelaxTunePrefs.bundle/RelaxTunePrefs` | 169792 | `8520cd0e89a7657f25e5cff6b3a53b77e0412df3183e312e1c08829c84d725d1` |
| `Library/PreferenceBundles/RelaxTunePrefs.bundle/icon.png` | 648 | `7cd0d67098887d63f29749371e691bb4055d2ebd550fd260c8f68104f50804d2` |
| `Library/PreferenceBundles/RelaxTunePrefs.bundle/icon@2x.png` | 1311 | `70b3aa60a1279c1ec60fb4a3744370dac31640011805ce4e0bc8ee8831c20255` |
| `Library/PreferenceBundles/RelaxTunePrefs.bundle/icon@3x.png` | 1994 | `fdc5e5a4809bcbc8dee1d07624e1f7da2ee8eb67312230b9828338c3ca0dae51` |
| `Library/PreferenceLoader/Preferences/RelaxTune.plist` | 188 | `cec708f83e19276990743727d96ff5a6530033a11d3ce0c7a0ed0357e54cf069` |
| `Library/ccSystem/system_tweaks.sh` | 3796 | `855a2a956ffc68d434f50f25c9299e840eeda478a37dc1960fef49b6438c60b7` |

## 4. 恰好四个原文件修改、两个文件新增

- `DEBIAN/control`：358 → 496 字节；原 SHA-256 `8acb533c3d058fdfce6cfde7ae6d6e2a6330a44112f44fc5ac4347086b4d65fc`；最终 `9f1ce20fb9e89e2001ceb82f9ea0ad793b1c9047982a7cba0a445a788ad43202`。
- `Library/MobileSubstrate/DynamicLibraries/RelaxTune.dylib`：206784 → 206784 字节；原 SHA-256 `9d3973e658fdd5edc1c1174de499842acfe7c6b25d9d9ee1ff0049c1d1e6329f`；最终 `de564b1f7b19e964647aa9565ba2d1c0de91881ef1a7f05b4f7f0189844a5b2f`。
- `Library/MobileSubstrate/DynamicLibraries/RelaxTune.plist`：113 → 465 字节；原 SHA-256 `45a2e0920c0ee087d47fdf640b03ffdae82050b4123c41e9521f1d6b2a16963f`；最终 `d2d7225973e568b4a6aac472d6b87cc2f04c481946ae11d087a3fa70056533f2`。
- `Library/PreferenceBundles/RelaxTunePrefs.bundle/Root.plist`：901 → 1085 字节；原 SHA-256 `36250823778f5a806c12a770c7c1fa78565568e90c57e1b0829819d93360ba34`；最终 `8d143f8e2aefe6fd6413886ef19afa923b2c50363f8a120d8d7f16bae35cd20e`。

- 新增 `Library/MobileSubstrate/DynamicLibraries/RelaxTuneProMotion120.dylib`：106272 字节；SHA-256 `ed0d0d483735bf0157cc848f5704a3925f2206c40a5ecea4f9b70b96611dddeb`。
- 新增 `Library/MobileSubstrate/DynamicLibraries/RelaxTuneProMotion120.plist`：329 字节；SHA-256 `73d6d16c4dfeca984eea330f6e9408fd8b4ced6dfa45cf779f8590ceee0718ed`。

新增 dylib 与包二 ProMotion120.dylib **完整字节相等**，并非仅抽样或只核对名字；精确匹配指定 ed0d0d483735bf0157cc848f5704a3925f2206c40a5ecea4f9b70b96611dddeb。新增 plist 内容故意不同于 donor，仅元数据沿用。

control 内容仅 Version 0.5→0.5.1、Installed-Size 404→482，并新增 Conflicts（com.doimty.promotion、cn.zqbb.fix120hz、cn.zqbb.fix120hz15、com.zqbb.fix120hz、com.zqbb.dynamic120hz）及 Tag: supports::roothide；其他原字段保留。data 普通文件总长度 492940 字节，向上取整 482 KiB 与 Installed-Size 相符。Root.plist 语义差异严格只有 HighRefresh 标签改为“ProMotion 120Hz（重启生效）”和动画组增加重启生效说明；所有开关键、默认值及其他设置保留。

## 5. 双架构旧入口 RET 与加载器

主 dylib 206784 字节，fat 中 arm64 slice 起点 0x4000、arm64e slice 起点 0x1c000；原/最终长度不变。函数起点来自 LC_FUNCTION_STARTS，refresh 名称来自真实符号表；旧 helper 的原始函数体读取 RTHighRefresh，并引用 setPreferredFrameRateRange: / setHighFrameRateReason:，不是只相信补丁坐标。

| 架构 | 旧入口 | VA | 绝对文件偏移 | 原四字节 → 最终 |
|---|---|---|---:|---|
| arm64 | old_helper | 0x6f08 | 44808 | `ffc300d1` → `c0035fd6` (RET) |
| arm64 | refresh_callback | 0x72e0 | 45792 | `ff8304d1` → `c0035fd6` (RET) |
| arm64e | old_helper | 0x72bc | 144060 | `7f2303d5` → `c0035fd6` (RET) |
| arm64e | refresh_callback | 0x76ec | 145132 | `7f2303d5` → `c0035fd6` (RET) |

| 架构 | 已注册 constructor | loader VA/绝对文件偏移/长度 | _RTLoadSettings | _dlsym stub | 原 epilogue | 调用指令 |
|---|---|---|---|---|---|---|
| arm64 | 0x7604 | 0x761c / 46620 / 116 | 0x7c10 | 0x81fc | 0x777c | BLR x16 |
| arm64e | 0x7a3c | 0x7a58 / 146008 / 116 | 0x810c | 0x8778 | 0x7bd8 | BLRAAZ x16 |

实际初始化表为 __init_offsets，不是假设存在 __mod_init_func：arm64=[0x4000,0x7604,0x7aa4]，arm64e=[0x4000,0x7a3c,0x7f80]。目标 constructor 确实在表中；原 prologue 和完整 epilogue 逐字不变。arm64e constructor 的 PACIBSP/AUTIBSP 及认证检查保留；旧 helper/refresh 是入口直接 RET，不会先执行旧 PAC/栈序言再错误退出。

加载器从真实指令解码出的逻辑为：

```text
_RTLoadSettings();
if (acquire_byte(_RTEnabled@0x10494) == 0) goto original_epilogue;
if (acquire_byte(_RTHighRefresh@0x10497) == 0) goto original_epilogue;
p = dlsym((void *)-2 /* Darwin RTLD_DEFAULT */, "dlopen");
if (p == NULL) goto original_epilogue;
p("@loader_path/RelaxTuneProMotion120.dylib", 6 /* RTLD_NOW|RTLD_LOCAL */);
goto original_epilogue;
```

两次 LDARB、两次开关 CBZ 和 dlsym 空值 CBZ 均由真实寄存器/立即数重建；字符串、调用 stub 由实际字节及间接符号表交叉定位。每架构对 Enabled×HighRefresh×dlsym_found 的 8 种组合，以真实指令操作数驱动抽象解释，共 **16/16 通过**；只有两开关均非零且 dlsym 非空才调用 dlopen，所有路径都回到原 epilogue。外部函数使用 mock，绝非执行了 iOS 或 PAC。实际 dlopen 返回结果没有运行验证；失败不会在本适配器中重试。

主 dylib 全量字节 diff 共 **380 字节不同**，且全部落在四个 4 字节 RET 区间、两个 116 字节 loader 区间和六个实际变化的代码页哈希槽中；不存在其他代码、数据、符号、初始化表或守卫改动。

## 6. 作用域与其他功能隔离

主 Filter 恰好是原 Filter 与包二 Filter 的保序去重并集：

- `com.apple.UIKit`
- `com.apple.springboard`
- `com.apple.UserNotificationsUIServer`
- `com.apple.springboard.SpringBoardOutofCallUI`

新增 provider Filter 只有 `com.12233sjjs.relaxtune.manual-loader-only`，为正常目标不匹配的哨兵，避免按原 donor 广泛自动注入；真实 provider 由主 dylib 显式加载。主 Filter 扩大按最新授权接受，其他功能可以随注入候选范围扩大，但**不绕过原进程守卫、各自开关或原动画屏蔽名单**。这是原有实现逐字保留的结论，不承诺每项功能覆盖每一个新增进程，也未把动画名单升级为所有功能总名单。HighRefresh 不成为其他功能的新增前置开关。

## 7. 页哈希独立重算

| 镜像 | 架构 | CodeDirectory slot | 算法 | codeLimit | 页大小 | 全部匹配槽数 |
|---|---|---:|---|---:|---:|---:|
| candidate | arm64 | 0 | sha1 | 90336 | 4096 | 23 |
| candidate | arm64 | 4096 | sha256 | 90336 | 4096 | 23 |
| candidate | arm64e | 0 | sha1 | 90336 | 4096 | 23 |
| candidate | arm64e | 4096 | sha256 | 90336 | 4096 | 23 |
| provider | arm64e | 0 | sha1 | 104352 | 4096 | 26 |
| provider | arm64e | 4096 | sha256 | 104352 | 4096 | 26 |

主 dylib：2 架构 × 23 物理代码页 × SHA-1/SHA-256 两套目录 = **92 个页哈希槽全部匹配**。原 provider：26 物理代码页 × 两套目录 = **52 个页哈希槽全部匹配**。92+52 指重复算法目录中的哈希槽计数，并非 144 个互异物理页。末页按 codeLimit 截断重算。另验证主 dylib 4 个、provider 2 个内嵌 requirements 特殊槽，全部匹配；所有目录 slot 1 为全零缺省。

相对原主 dylib，恰好以下六个哈希槽发生变化（页号从 0 开始）：

| 绝对文件偏移 | 字节 | CodeDirectory slot | 页号 |
|---:|---:|---:|---:|
| 107038 | 20 | 0 | 6 |
| 107058 | 20 | 0 | 7 |
| 107908 | 32 | 4096 | 6 |
| 107940 | 32 | 4096 | 7 |
| 205362 | 20 | 0 | 7 |
| 206244 | 32 | 4096 | 7 |

两镜像的 SuperBlob 均仅包含主 CodeDirectory、requirements、alternate CodeDirectory，未见 CMS wrapper (0x10000)。页哈希和 requirements 自洽仅说明嵌入摘要与对应字节一致，**不代表已有受信任签名，也不证明 AMFI/trust cache/越狱信任接受**。

## 8. 保留限制

- 未做 iOS 实机安装、SpringBoard/App 启动、真实 dyld 路径解析、PAC 认证调用、AMFI/trust cache 接受、RootHide 注入器策略或实际帧率测试。
- provider 本身为完整保留的 **thin arm64e**（cpusubtype=0x80000002），没有新增 arm64 provider。双架构通过指主 dylib 两个 slice 的补丁/门控/页哈希通过，不能外推为 provider 可用于纯 arm64 进程。
- Enabled/HighRefresh 是启动时加载门控；修改后须重载 SpringBoard 并重新打开 App，不声称热卸载或即时切换。
- 本次仅审计指定 DEB，不证明当前源码能重新构建出相同字节，不替代源代码 CI 或真机回归。

**最终判定：归档所有权与元数据 21/21 保持；七个原无关文件不变；四改两增准确；donor 完整一致；双架构 RET/门控和 92+52 页哈希静态通过。运行与信任状态未验证。**
