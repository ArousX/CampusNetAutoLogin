# CampusNet Auto Login for Windows

Windows 11 启动时自动执行 Dr.COM 校园网认证。

> 适用于已经确认认证接口为 `http://172.30.100.2/drcom/login`，成功响应为 `dr1003({..."result":1...})` 的网络环境。

## 功能

- 系统启动后延迟 5 秒执行一次；
- 任务以 `SYSTEM` 身份运行，不需要用户登录 Windows；
- 使用本机 DPAPI 加密保存凭据；
- 仅允许 `SYSTEM` 与本机管理员访问凭据文件；
- 禁用代理、Cookie 和 HTTP 自动重定向；
- 不打开浏览器，不记录账号、密码、完整 URL 或响应内容；
- 认证失败不会无限重试，也不会监听断网重连。

## 安全提醒

该 Dr.COM 接口使用 HTTP GET，密码会出现在 HTTP 查询参数中。本项目只保护本机磁盘上的静态凭据，不能保护校园网链路中的传输内容。请不要使用与邮箱、支付账户相同的密码，并确认你有权使用该网络接口。

不要把以下内容提交到 GitHub：

- 真实账号或密码；
- `credential.bin`；
- 带 `upass=` 的完整 URL；
- 任务导出 XML；
- 运行日志或截图。

## 安装

1. 下载或克隆本项目。
2. 以管理员身份打开 **Windows PowerShell 5.1**。
3. 进入项目目录，例如：

   ```powershell
   Set-Location 'C:\路径\CampusNetAutoLogin'
   ```

4. 运行安装脚本：

   ```powershell
   .\Install-CampusNetAutoLogin.ps1
   ```

5. 按提示输入校园网账号和密码。密码输入时不会显示。
6. 安装脚本会创建任务 `CampusNetAutoLoginAtStartup`，并立即启动一次测试。

安装脚本不会把账号密码写入 GitHub 项目；密码会以本机 DPAPI `LocalMachine` 方式保存到：

```text
C:\ProgramData\CampusNetAutoLogin\credential.bin
```

## 验证

管理员 PowerShell 中执行：

```powershell
Get-ScheduledTaskInfo -TaskName CampusNetAutoLoginAtStartup
```

`LastTaskResult : 0` 表示认证接口返回 `result=1`。

检查触发器：

```powershell
$t=Get-ScheduledTask -TaskName CampusNetAutoLoginAtStartup; $t.Principal | Format-List UserId,LogonType,RunLevel; $t.Triggers | Format-List Delay,CimClass
```

应看到 `SYSTEM`、`ServiceAccount`、`Highest`、`MSFT_TaskBootTrigger` 和 `PT5S`。

## 卸载

以管理员身份运行：

```powershell
.\Uninstall-CampusNetAutoLogin.ps1
```

卸载会删除计划任务和 `C:\ProgramData\CampusNetAutoLogin` 中的本机凭据。

## 退出码

| 代码 | 含义 |
|---:|---|
| 0 | 收到有效 JSONP 且 `result=1` |
| 10 | 启动等待窗口内网关不可达 |
| 12 | 凭据不存在或无法解密 |
| 13 | HTTP 请求失败或状态码非 200 |
| 14 | JSONP 格式无效或认证结果非成功 |
| 15 | 未分类脚本异常 |

## 许可

建议上传前根据你的学校政策选择许可证，并在 README 中保留 HTTP 明文传输风险说明。
