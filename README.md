# Box for Root

`Box for Root` 是一个面向 Android Root 环境（Magisk / KernelSU / APatch）的透明代理工具箱模块。

项目深受以下仓库启发并在其基础上持续演进：
- [CHIZI-0618/box4magisk](https://github.com/CHIZI-0618/box4magisk)
- [CHIZI-0618/AndroidTProxyShell](https://github.com/CHIZI-0618/AndroidTProxyShell)
- [taamarin/box_for_magisk](https://github.com/taamarin/box_for_magisk)


### split-apps + Dual AdGuard Home

实验性 `dns_hijack_mode="split-apps"` 可将白名单应用 DNS 送到 Foreign AGH :5592，其余应用 DNS 送到 Domestic AGH :5591。运行中实例故障会动态回退：Domestic 故障恢复系统 DNS，Foreign 故障回退 Mihomo :1053；两种国外后端都不可用时白名单 DNS fail-closed。独立 `box/scripts/dns-rescue.sh` 可无条件移除 Box DNS hooks。

验证步骤见 [docs/split-apps-agh-validation.md](docs/split-apps-agh-validation.md)。

## 项目定位

本仓库主要提供：
- 统一的代理核心运行管理（mihomo / sing-box / xray / v2fly / hysteria）
- 多网络模式下的透明代理规则编排（TProxy / Redirect / Tun / Mixed / Enhance）
- 订阅、Geo 资源、核心二进制与 WebUI 的统一维护脚本
- 适配 Android Root 生态的模块化目录与服务生命周期管理

## 主要目录

模块工作目录：`/data/adb/box/`

```text
/data/adb/box/
├── bin/                # 代理核心与工具二进制
├── mihomo/             # mihomo 配置目录
├── sing-box/           # sing-box 配置目录
├── xray/               # xray 配置目录
├── v2fly/              # v2fly 配置目录
├── hysteria/           # hysteria 配置目录
├── scripts/            # 核心脚本
│   ├── box.service     # 服务生命周期管理
│   ├── box.iptables    # 透明代理规则管理
│   └── box.tool        # 更新与维护工具集
├── run/                # 运行时状态与日志
└── settings.ini        # 全局配置文件
```

## 核心脚本

- `box.service`: 启停、重启、状态与定时任务控制
- `box.iptables`: 透明代理规则启用、重建、清理
- `box.tool`: 订阅更新、Geo 更新、核心更新、配置检查、WebUI 相关维护

## 应用级 DNS 分流（实验）

开发分支支持 `dns_hijack_mode="redirect-apps"`，用于 Root 透明代理下按应用 UID 分流 DNS，而不依赖 Android `VpnService`。

工作方式：

```text
代理应用 UID
  -> Android DnsResolver
  -> boxbpf / bpf_get_socket_uid()
  -> REDIRECT 到本地核心 DNS

非代理应用 UID
  -> 不命中 eBPF matcher
  -> 保持 Android / 当前网络 DNS
```

当前第一版支持 `redirect / tproxy / mixed / enhance` 网络模式，暂不支持 `tun / ebpf` 网络模式。

启用前先安装 eBPF matcher：

```sh
/data/adb/box/scripts/box.tool upboxbpf
```

然后在 `/data/adb/box/settings.ini` 中配置：

```sh
proxy_mode="whitelist"
dns_hijack_mode="redirect-apps"
```

并在 `package.list.cfg` 中填写需要代理的应用包名。模块启动时会动态解析 UID，应用重装后无需手工维护固定 UID。

如果设备不支持 `xt_bpf`、无法加载 `boxbpf` 或 UID 列表为空，`redirect-apps` 会停止规则应用，不会回退为全局 DNS 劫持。

## 文档与社区

- Wiki: <https://github.com/boxproxy/box/wiki>
- 更新日志: [CHANGELOG.md](./CHANGELOG.md)
- 配套 APP / 通知频道: <https://t.me/zero_o0>

## 致谢

感谢开源社区与上述项目作者提供的设计思路与实现参考。
