## 方式1️⃣：不想自己操作?直接把下面这段 prompt 发给你的 agent🤖:

```
使用这个项目为我的 Chrome 启用 Gemini AI:https://github.com/elianafang/chrome-open-Gemini。配置完成后,请验证 Gemini AI 是否正常可用,以及国内网站能否正常访问。
```

## 方式2️⃣：Chrome 一键开启 Gemini(macOS / Windows)

✨ 双击即可让 Chrome 里的 Gemini 可用 ✨



### 🚀 使用步骤

1. 点 **Code → Download ZIP**,解压
2. 打开代理软件,开启**系统代理**,节点选**美国**
3. 双击启动脚本
   - macOS:**开启Gemini.command**
   - Windows:**开启Gemini.bat**
4. *(选做)* 国内网站打不开?在 Shadowrocket 里让国内网站直连。已有正常配置时，优先在原配置中添加所需域名规则，见下方说明。需要独立配置时，先备份原配置，再导入本仓库的专用配置:
   1. 配置 → 右上角 **+** → 粘贴下面的地址并下载
      ```
      https://raw.githubusercontent.com/elianafang/chrome-open-Gemini/main/shadowrocket-gemini.conf
      ```
   2. 点这个配置 → **使用配置**
   3. 首页 → 全局路由改为 **配置**，选择可用的美国节点，断开后重新连接
   4. 分别验证 Gemini、国内网站、Codex 和 GitHub；出现异常时切回备份配置

### Shadowrocket 配置说明

[专用配置](shadowrocket-gemini.conf) 使用系统 DNS、保留 IPv6，并让 `198.18.0.0/15` 虚拟 IP 网段留在隧道内。Google、OpenAI、Claude 和 GitHub 明确走代理；AutoDL、SeetaCloud 及国内目标直连，其余流量走所选代理节点。不启用 HTTPS 解密。

旧教程推荐的第三方整份配置会同时改变 DNS、IPv6 和隧道排除网段，可能与 macOS 当前网络环境冲突，因此不再推荐直接替换使用。新配置已做静态检查，尚未完成真实隧道下的连通性验证，也不能保证节点出口一定可用。

如果现有默认配置正常，只需在原配置的 `[Rule]` 顶部、其他规则之前按需加入：

```ini
DOMAIN-SUFFIX,google.com,PROXY
DOMAIN-SUFFIX,googleapis.com,PROXY
DOMAIN-SUFFIX,gstatic.com,PROXY
DOMAIN-SUFFIX,googleusercontent.com,PROXY
DOMAIN-SUFFIX,autodl.com,DIRECT
DOMAIN-SUFFIX,autodl.ai,DIRECT
DOMAIN-SUFFIX,seetacloud.com,DIRECT
```

保留原配置的 DNS、IPv6 和隧道设置，并使用“配置”路由模式。这些规则也可在 App 的配置编辑页面逐条添加。

> macOS 提示"无法打开"?右键文件 → 打开
> Windows 提示"已保护你的电脑"?点 **更多信息 → 仍要运行**

---

## ⚠️ 注意

- 需要 Chrome 147 及以上,并已登录 Google 账号
- 以后请用脚本启动 Chrome,不要直接点 Dock / 桌面图标,否则配置会被重置
- 关闭 Gemini:双击 **关闭Gemini.command** / **关闭Gemini.bat**

## ❓ 常见问题

**提示节点被风控?** 换一个节点再试。不是地区问题,是这个 IP 被 Google 标记了。

## ⭐ Star 趋势

[![Star History Chart](https://api.star-history.com/image?repos=elianafang/chrome-open-Gemini&type=Date)](https://www.star-history.com/#elianafang/chrome-open-Gemini&Date)

图表自动更新，可能因缓存稍有延迟。点击图表可查看完整的 Star 历史。
