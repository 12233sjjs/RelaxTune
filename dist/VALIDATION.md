# 0.5.1 本地交付验证 — 2026-11-26

## 已通过

- 两份输入 DEB 整包 SHA-256 和原主 dylib 身份匹配。
- `tests/test_preferences.py`：源设置与实际解包内容均通过。
- `tests/test_promotion_adapter.py`：供体原字节、主/辅助 Filter、启动双开关、旧高刷停用、打包内容、其他功能不依赖高刷开关均通过。
- `tests/test_kernel_script.py`：8 项通过。
- `test_core` 与 `test_network`：本地严格编译并通过。
- 两个主 dylib 切片各 512 组隔离加载器模拟，共 1024 组通过。arm64e 测试只修改测试内存副本以归一化认证调用，不代表实际 PAC 执行通过。
- 最终独立只读审计 `FINAL-STATIC-REPORT.md`：PASS_STATIC，21/21 原条目的指定元数据保持；七个无关原文件逐字保留；四改两增；主库 92 个及供体 52 个 CodeDirectory 页哈希槽一致。
- 两个独立输出目录构建出的 50,070 字节 DEB 哈希一致：`d9d430c5327ecdffa8e1c821e479a76571ff4cfba9ff686f9f09b9789839b375`。
- `git diff --check` 通过。已修正动画 fixture 与现有生产行为相反的陈旧断言；未改相关生产业务逻辑。

## GitHub CI 与验收边界

- 本机仍为 Linux；macOS Foundation / Logos 动画 fixture 和 Theos 源码构建由 GitHub Actions 执行。
- 分支首次运行 `45732550494` 的 Linux 核心、设置、网络及内核脚本测试通过；macOS 动画 fixture 因模拟类 `BSAnimationSettings` 与系统 BaseBoard 同名而失败，尚未生成源码重建安装包。该失败不改变上述预构建 DEB 的静态审计结论。
- 后续 CI 将隔离测试模拟类命名，并固定有效的 RootHide Theos 提交、记录真实工具链版本。最新完成状态及源码重建包以本分支对应的 [GitHub Actions](https://github.com/12233sjjs/RelaxTune/actions?query=branch%3Acodex%2Frelaxtune-0.5.1-promotion120-20261126) 为准，不把预构建包冒称为 CI 重建产物。
- 未做越狱 iPhone 安装、真实 dyld/PAC/AMFI/RootHide 信任、刷新率、FPS、发热或功耗测试。

## 上传状态

独立分支：`codex/relaxtune-0.5.1-promotion120-20261126`。

2026-11-26 08:58 更新令牌后，已实际验证 Contents 写权限，并成功推送至 `12233sjjs/RelaxTune`；首次远端提交为 `7ab0308d6d36899f268da37284ad5b0b536d32a9`。之前的 HTTP 403 阻塞已经解除。

已从 GitHub API 读回 `dist/com.12233sjjs.relaxtune_0.5.1_iphoneos-arm64e.deb`，50,070 字节及 SHA-256 均与本地静态审计包一致。**main 未修改；尚未创建远端标签或 Release。** 测试环境修复不会替换已审计预构建 DEB。
