# 排错与恢复

## Android 版本与兼容性

本项目的最低版本为 API 17，真机测试为 Android 4.2.1。厂商的 Smart OS 编号不是 Android 版本。以 `adb shell getprop ro.build.version.release` 和 `ro.build.version.sdk` 为准。

MS901 的厂商组件、信源切换和声音接口并非通用 Android API。其他电视即使能安装 APK，也可能需要适配组件和声音逻辑；Windows 安装脚本会拒绝未经验证的配置。

## 机顶盒没有频道

节目来自 HDMI/AV 外接机顶盒时，应使用原来接线对应的信源，无需在电视的模拟/数字调谐器内搜台。本机是 HDMI1。桌面调用原厂电视活动，恢复电视记忆的信源；文字标签不会强制把记忆信源改成 HDMI1。

## 回主页仍有机顶盒声音

这台旧 TCL 的 HDMI 音频没有被普通 `STREAM_MUSIC` 静音挡住，原厂电视也没有通过常规音频焦点接口停止它。当前实现对 API17 / tcl_901 调用原机 `TTvCommonManager.setInputSource(EN_TCL_STORAGE, false)`，切换到应用模式而不覆盖记忆输入。

这次实测耗时约 3 秒。相同方法在其他固件上未验证；接口不存在时会记录错误而不强制改音量。不要以全局永久静音代替输入模式的正确切换。

## 安装失败

- 先确认电视是 API 17 及本项目已验证配置。
- 使用固定英文临时路径再 `pm install -r`；安装脚本已处理这一点。
- `INSTALL_FAILED_UPDATE_INCOMPATIBLE` 通常意味着同包名但签名不同。使用原密钥构建更新，或在明确要更换版本时先移除旧的 `local.tv.simplehome`；不要卸载原厂桌面。
- API17 需要 v1 签名，构建脚本调用 `apksigner verify --min-sdk-version 17` 检查。

签名与对齐顺序参考 [Android 官方 apksigner 文档](https://developer.android.com/tools/apksigner)。

## 某个视频入口打不开

首页三个视频入口使用本机的 `com.ktcp.video`、`com.tcl.qiyiguo`、`com.cibn.tv`。未安装这些包时会提示入口不可用；可以从“全部应用”打开自己的 App，或修改源码中的入口。项目不提供视频 App 安装包。

## 退出应用后还有进程

先区分应用页面、Android 服务、缓存进程和独立原生进程。正常退出不保证所有辅助进程同时消失。具体实测及判断依据见[性能案例](performance.md)；不建议仅凭进程数量自动强杀。

## 恢复原厂桌面

```powershell
.\scripts\Restore-Launcher.ps1 -Serial "<电视IP>:5555"
```

脚本先启动 `com.tcl.cyberui/.MainActivity`，确认成功后只卸载本项目的 `local.tv.simplehome`。当前也可在简洁桌面点“原厂桌面”，或按返回键打开它。

如果原厂桌面本来已被其他工具停用，应先在原工具中恢复它；本项目安装流程不负责改动其他工具的停用状态。

## 系统包与开机广告

本次开机广告没有关闭。不能把其他项目对新机型的 `pm disable-user` 成功记录当成本机的结果，也不能把仅仅“命令执行过”写成停用成功。

按用户要求移除的两个系统包，另有[专用恢复说明](../profiles/tcl-ms901/README.md)。恢复 APK 不等于保证恢复账号、缓存或其他应用数据。
