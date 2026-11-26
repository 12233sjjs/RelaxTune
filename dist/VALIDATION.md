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

## 未执行 / 不保证

- 当前为 Linux 环境，未执行 macOS Foundation / Logos 的动画 hook fixture。
- GitHub Actions 尚未触发；源码 Theos 构建未在本轮运行。
- 未做越狱 iPhone 安装、真实 dyld/PAC/AMFI/RootHide 信任、刷新率、FPS、发热或功耗测试。

## 上传状态

独立本地分支：`codex/relaxtune-0.5.1-promotion120-20261126`。

GitHub 仓库：`12233sjjs/RelaxTune`。账号层 repo API 返回 push=true，但实际令牌写请求被拒绝；不能把账号权限当作令牌已获写入授权。用户确认更新令牌后，Git push 与 REST 创建分支仍返回 HTTP 403（`Resource not accessible by personal access token`；响应要求 contents=write / workflows=write）。

**尚未上传分支、创建远端标签或 Release；main 未被本任务修改。** 交付文件均保留在共享目录，可在有效仓库写授权后继续，无需重建 DEB。
