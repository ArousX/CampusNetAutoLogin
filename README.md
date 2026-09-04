# 校园网自动登录（Windows）

Windows 启动后自动完成 Dr.COM 校园网认证。

适用接口：`http://172.30.100.2/drcom/login`，成功标志：返回内容中的 `result=1`。

## 功能

- 开机后约 5 秒自动执行一次；
- 不需要登录 Windows；
- 账号密码使用 Windows DPAPI 加密保存；
- 不打开浏览器；
- 不记录账号、密码和完整认证网址；
- 失败后不会无限重试，也不会监测断网重连。

## 安全提示

该接口使用 HTTP GET，密码会出现在网络请求参数中。本项目只能保护电脑上的凭据，不能加密校园网链路。请勿使用重要账户的相同密码，并仅在获授权的网络环境中使用。

请勿将以下内容上传到 GitHub：

- 账号和密码；
- `credential.bin`；
- 带 `upass=` 的完整网址；
- 日志、截图或任务 XML。

## 安装

1. 下载本项目。
2. 以管理员身份打开 Windows PowerShell 5.1。
3. 进入项目目录：

   ```powershell
   Set-Location 'C:\项目路径\校园网自动登录'
   ```

4. 执行安装脚本：

   ```powershell
   .\Install-CampusNetAutoLogin.ps1
   ```

5. 按提示输入校园网账号和密码。密码不会显示。

安装脚本会创建计划任务：

```text
CampusNetAutoLoginAtStartup
```

加密凭据保存在：

```text
C:\ProgramData\CampusNetAutoLogin\credential.bin
```

## 验证

以管理员身份执行：

```powershell
Get-ScheduledTaskInfo -TaskName CampusNetAutoLoginAtStartup
```

看到下面结果表示认证成功：

```text
LastTaskResult : 0
```

## 卸载

以管理员身份执行：

```powershell
.\Uninstall-CampusNetAutoLogin.ps1
```

卸载会删除计划任务及本机保存的加密凭据。

## 退出码

| 代码 | 含义 |
|---:|---|
| 0 | 认证成功 |
| 10 | 网关不可达 |
| 12 | 凭据不存在或无法解密 |
| 13 | HTTP 请求失败 |
| 14 | 认证响应无效或登录失败 |
| 15 | 脚本异常 |
