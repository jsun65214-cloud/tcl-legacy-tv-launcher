# 安装与连接

## 适用范围

真机是 TCL E5690 系列、MS901 主板、Android 4.2.1 / API 17、固件 V8-MS90104-LF1V219。厂商显示的 Smart OS 4.2.9 Plus 不是 Android 版本号。安装工具会核对设备 `tcl_901`、主板 `BD_MST036B_D0ABIV_TCL_901` 和 API 17。

先只查看信息。不同电视的开发者选项、信源、设置组件和调试接口可能不同；本项目没有全品牌适配层。

## 准备

1. 电脑与自己的电视在同一局域网，记下电视当前地址。
2. 下载 Google 官方 [Platform Tools](https://developer.android.com/tools/releases/platform-tools)，将 `adb.exe` 加入 PATH，或向脚本传 `-Adb "<adb.exe完整路径>"`。
3. 在电视的正常设置里开启并授权调试连接。新款“无线调试配对码”流程不能直接套到 Android 4.2.1 上。
4. 用 `adb devices` 查看设备，随后每条电视命令都明确指定 `-s "<电视IP>:5555"`。不要运行 `adb kill-server`，以免影响其他正在连接的设备。

## 旧版 MS901 调试入口案例

这次实机没有找到菜单中的 ADB 开关。它原本存在旧版 TCL 调试控制端口 8090，在同一可信局域网、确认目标是自己的电视后，发送 `start adbd` 能启动临时 ADB。这是特定旧固件的已验证现象，其他型号不应假定有同一接口。

可在 PowerShell 定义以下函数，只给它传自己的电视地址：

```powershell
function Send-LegacyTclCommand([string]$TvAddress, [ValidateSet('start adbd','stop adbd')][string]$Command) {
    $client = [Net.Sockets.TcpClient]::new()
    try {
        if (-not $client.ConnectAsync($TvAddress,8090).Wait(3000)) { throw '连接超时' }
        $stream = $client.GetStream()
        $stream.ReadTimeout = 2500
        $bytes = [Text.Encoding]::ASCII.GetBytes($Command + "`n")
        $stream.Write($bytes,0,$bytes.Length)
        $buffer = [byte[]]::new(256)
        $length = $stream.Read($buffer,0,$buffer.Length)
        [Text.Encoding]::ASCII.GetString($buffer,0,$length).Trim()
    } finally { $client.Dispose() }
}
Send-LegacyTclCommand -TvAddress '<电视IP>' -Command 'start adbd'
adb connect "<电视IP>:5555"
```

这个案例的公开实践参考：[旧款 TCL 的 ADB 与桌面切换记录](https://www.cnblogs.com/bearhuchao/p/18455216/TCL-AnyLauncher)。本项目没有自动扫描局域网或自动执行该控制命令。

## 安装桌面

从 [Release 页面](https://github.com/jsun65214-cloud/tcl-legacy-tv-launcher/releases/latest) 下载 APK 与 SHA256SUMS。用下面的结果与校验文件比较：

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath .\legacy-tv-home-1.0.apk
.\scripts\Install.ps1 -Serial "<电视IP>:5555" -Apk .\legacy-tv-home-1.0.apk
```

脚本使用固定英文临时路径传 APK，再调用 `pm install -r`；旧机直接处理中文安装文件名时可能暂存失败。它保留原厂桌面，不获取 root，不清理视频应用。

在电视上确认：

- 左右方向键能移动选中框，确认键能打开应用。
- “原厂桌面”和设置、信号源入口能用。
- 机顶盒连接的 HDMI 输入画面、声音正常。
- 按主页回简洁桌面后背景声音停止，重新打开机顶盒后声音恢复。

确认后按电视主页键，在系统的桌面选择框里选择“简洁电视桌面”和“始终”。“机顶盒 · HDMI1”标签对应本次实际接线；底层恢复电视记忆的信源。若改接 HDMI2，请在信号源选择相应输入，并按自己的接线修改源码标签。

## 使用完后关闭调试

普通桌面安装不使用 root。若自己执行过高级步骤，先按照[高级机型说明](../profiles/tcl-ms901/README.md)退出临时管理员权限。

通过菜单关闭调试，或在这个确实提供旧版接口的固件上调用：

```powershell
Send-LegacyTclCommand -TvAddress '<电视IP>' -Command 'stop adbd'
```

连接被断开并不等于关闭已确认：再用 TCP 连接检查 5555 应被明确拒绝，超时则是状态不确定；不要把 `adb disconnect` 当成关闭电视上的调试服务。

## 恢复原厂首页

重新连接、授权 ADB 后执行：

```powershell
.\scripts\Restore-Launcher.ps1 -Serial "<电视IP>:5555"
```

脚本先打开原厂桌面，再只卸载 `local.tv.simplehome`。它不恢复后来单独移除的其他应用；两个预装包的恢复方法见[对应机型目录](../profiles/tcl-ms901/README.md)。
