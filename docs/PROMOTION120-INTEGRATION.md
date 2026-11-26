# 0.5.1 ProMotion120 集成与交付说明

日期：2026-11-26。用户在本次接续中明确“其他功能也扩大，并继续上传打包”。这里的扩大指**主注入进程范围**，不提高动画倍率上限，不强制开启任何功能。

## 范围与开关

主 Filter 保留 `com.apple.UIKit`、`com.apple.springboard`，合并供体的 `com.apple.UserNotificationsUIServer` 和 `com.apple.springboard.SpringBoardOutofCallUI`。现有非高刷功能也允许在新增的合格进程中运行，但仍遵守原 `.app`/SpringBoard 等进程守卫、总开关、对应功能开关和动画屏蔽名单。不是所有功能都会覆盖所有新增进程，也不绕过 Relaxin/RootHide 注入器策略。

- 动画、唤醒/解锁、网络等待、TCP_NODELAY、僵尸清理与手动内核脚本的业务实现不改；旧动画帧率写入 helper 除外，其已停用。
- 唤醒/解锁及僵尸清理仍限其原 SpringBoard 路径；内核脚本仍须手动执行；音效仍不编译、不打包。
- 旧高刷 callback 和 helper 入口均改为返回；双切片 constructor 在加载设置后，仅在 `Enabled && HighRefresh` 时通过 `dlsym`/`dlopen` 加载原样 ProMotion 模块，不叠加旧 hook。
- 供体使用一个普通目标进程不匹配的 helper Filter，避免自动注入绕过开关；此 Filter 不是抵御外部手动加载器的安全边界。
- 高刷或总开关变更后必须**重载 SpringBoard 并重新打开目标 App**。不对已安装的 Substrate hooks 做 `dlclose` 热卸载。
- 供体自己的设备检查、刷新策略和持续 keepalive 原样保留，可能增加功耗、发热；不承诺低电量时沿用包一的旧撤销策略，不保证面板一直 120Hz 或游戏 120FPS。

## 两份精确输入

| 输入 | SHA-256 |
| --- | --- |
| RelaxTune 0.5 RootHide DEB | `d5130ca773d45b45ca48e61781b88365a0492b93eec3ce84519d389c348b8403` |
| ProMotion 120Hz 1.0.14-1 RootHide DEB | `b96bfa462178b034897400cec04cdbd334a27453f8582f6738de0dc6e7c741ff` |
| 原包一主 dylib | `9d3973e658fdd5edc1c1174de499842acfe7c6b25d9d9ee1ff0049c1d1e6329f` |
| 原样供体 dylib | `ed0d0d483735bf0157cc848f5704a3925f2206c40a5ecea4f9b70b96611dddeb` |

本次通过原 GitHub Actions artifact `14632191058`（运行 `44737080608`）和作者公开 APT 仓库 `doimty/doimty.github.io` 恢复原文件；四个哈希与前会话记录全部精确匹配，并非近似版或重新构建版。

最终预构建文件：`dist/com.12233sjjs.relaxtune_0.5.1_iphoneos-arm64e.deb`，50,070 字节，SHA-256：

```text
d9d430c5327ecdffa8e1c821e479a76571ff4cfba9ff686f9f09b9789839b375
```

仅交付 iOS 16.x / Relaxin、RootHide 的 `iphoneos-arm64e` 包；不是标准 rootless 包。主库含 arm64/arm64e 切片，不表示供体能在不支持其策略的设备上生效。

## 修改边界与元数据

四个原有文件内容变化：`RelaxTune.dylib`、其主 Filter、设置面板 `Root.plist` 和 `DEBIAN/control`；新增原样 `RelaxTuneProMotion120.dylib` 及手动加载专用 Filter。其他七个原文件字节和原文件模式不变。

保留全部 21 个原 control/data tar 条目的数值 uid/gid、uname/gname、mode、mtime、type 和 linkname；新增两个条目沿用供体元数据。原包有“数值 501:20、文本 root/wheel”的元数据，不能仅以 `dpkg-deb --contents` 的名字显示断言其数值所有权。这些字段及路径语义得到保留，但不声称原始 tar header 逐字不变：USTAR/GNU 路径表示、目录尾斜线和八进制填充会被重新编码。避免依赖虚拟文件系统 `chown` 或 `--root-owner-group` 静默归零；沿用原 control gzip / data LZMA 编码。完整边界见 `dist/FINAL-STATIC-REPORT.md`。

## 本地复现与检查

`tools/promotion120/patch_refresh.py` 固定两份输入 SHA-256。依赖 Python 3.11+、capstone、GNU AArch64 `as`/`objcopy`、dpkg-deb。原始两个 DEB 不在源码树重复存储：

```sh
python3 tools/promotion120/patch_refresh.py \
  --package1 /path/to/RelaxTune-0.5.deb \
  --package2 /path/to/ProMotion120-1.0.14-1.deb \
  --out /path/to/fresh-output-directory
python3 tests/test_preferences.py
python3 tests/test_promotion_adapter.py
python3 tests/test_preferences.py /path/to/fresh-output-directory/reextracted
python3 tests/test_promotion_adapter.py /path/to/fresh-output-directory/reextracted
```

随附 `dist/PROMOTION120-AUDIT.json`、`dist/SHA256SUMS` 和验证说明。主库 92 个、供体 52 个 CodeDirectory 页摘要重新核验；这只是摘要一致性，**不是 Apple CMS、AMFI 或越狱信任链已验证**。1024 组隔离加载器测试均拦截 Apple/dyld 调用：arm64 512 组，arm64e 512 组；后者仅测试内存副本归一化认证调用，不修改交付库，不声称实际 PAC 执行通过。

此 DEB 是对指定输入包的二进制最小适配。源码分支基于 `3189eefef925a402d9f275fa39728872bc563756` 提供下一次 Theos 重建的等价启动适配器；不能把该重建描述为与预构建 DEB 字节相同。正式 CI 在独立分支执行测试与 Theos 源码构建，结果以相应 GitHub run 为准。

## 验收边界与归属

没有连接越狱 iPhone，未安装或加载本包，未实测刷新率、FPS、耗电、温控、黑屏或 SpringBoard 稳定性。首次安装前保留旧 DEB；如有异常，禁用/卸载本插件。不要同时安装冲突列表中的其他高刷插件。

RelaxTune 源码许可见项目 GPL 文件。`RelaxTuneProMotion120.dylib` 来自 doimty 的独立二进制，保持原字节及归属；不把此模块冒称为本项目原创或已获得其源码。其原包元数据和精确哈希记录在输入恢复审计中。
