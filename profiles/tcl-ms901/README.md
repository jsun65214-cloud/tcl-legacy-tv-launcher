# MS901 / API 17 高级可选操作

这组脚本来自同一次 Android 4.2.1 真机实践，只处理两个指定预装包；普通安装桌面和性能诊断不会执行它们。

| 条件 | 本次实测值 |
| --- | --- |
| Device | tcl_901 |
| Board | BD_MST036B_D0ABIV_TCL_901 |
| Android / API | 4.2.1 / 17 |
| 厂商固件 | V8-MS90104-LF1V219 |
| system 分区 | /dev/block/mmcblk0p4，ext4 |

## 两个目标与备份

| 应用 | 包名 | 原 APK |
| --- | --- | --- |
| ATET游戏大厅 | com.sxhl.tcltvmarket | /system/app/TCL_TV_MARKET.apk |
| 云视听 | com.voole.epg | /system/app/TCL_901_708_2.70.0_201611091412_VOOLEPLAYAPK_2.5.02_GENERIC_20161108.151811.apk |

先保存自己的包状态，并把两个原 APK 拉到电脑，核对名称与版本。项目不附带这些原厂 APK。两者在本次实机上的版本分别为 3.4.87 和 2.5.0；不要依据显示名称相似就删腾讯视频、其他游戏中心或电视核心服务。

## 权限与移除方式

在实机上，普通卸载返回 Failure，停用被 uid2000 的权限检查拒绝。用户明确同意进一步处理后，设备自带 `adb root` 成功；没有使用漏洞或刷机。这不意味着所有量产电视都支持该命令。

本步骤需要所有者明确授权，并已准备好两个 APK 的电脑备份。脚本要求临时管理员身份、核对机型/API和分区；将两个 APK 移到 `/system/app-disabled-20261025/`，离开应用扫描目录，保留原包用于恢复，不自动重启。

```powershell
adb -s "<电视IP>:5555" root
# 等调试服务重启，再重新连接并用 shell id 确认身份。
adb connect "<电视IP>:5555"
adb -s "<电视IP>:5555" shell id
adb -s "<电视IP>:5555" push .\profiles\tcl-ms901\remove-preinstalled.sh /data/local/tmp/tv-remove-preinstalled.sh
adb -s "<电视IP>:5555" shell sh /data/local/tmp/tv-remove-preinstalled.sh
```

成功需同时看到 `REMOVAL_VERIFIED`、`TASK_EXIT=0`，并独立确认完整安装清单仍有原机电视和桌面、没有两个目标；`/system` 必须恢复只读。失败时脚本尝试移回已移动的目标并恢复只读；如果恢复没有完成，应根据保留的原 APK 处理，不能把失败状态当作成功。

源文件与目的文件冲突时脚本会停止，不能反复覆盖运行。普通程序与备份保留在同一分区，这个方式不是用来释放 APK 所占存储空间。

## 恢复

重新连接同一设备、取得其自带临时管理员权限后：

```powershell
adb -s "<电视IP>:5555" push .\profiles\tcl-ms901\restore-preinstalled.sh /data/local/tmp/tv-restore-preinstalled.sh
adb -s "<电视IP>:5555" shell sh /data/local/tmp/tv-restore-preinstalled.sh
```

恢复支持逐包重试，只移动缺失且有备份的目标，验证两个包重新出现在有效的安装清单中，再恢复系统只读。脚本不主动清数据，但 Android 可能在移除后或以后启动时自行清理这些应用的数据；这里保证保留的是原 APK，不承诺保留登录、缓存等。相关 Android4.2 行为见 [AOSP PackageManagerService](https://github.com/aosp-mirror/platform_frameworks_base/blob/android-4.2.2_r1/services/java/com/android/server/pm/PackageManagerService.java)。

## 原生残留与权限收尾

云视听在本次移除后留下了 `videodaemon`、`vooleauthd`。需要确认它们的 UID 和 `/proc/<PID>/exe` 确实属于目标应用后才处理；**不要复用别人的 PID 数字**。移除脚本不按进程名称猜测并批量终止，也不会终止腾讯视频辅助进程。

旧版 adbd 不一定支持 `adb unroot`。本机采用把 `service.adb.root` 设回 0，再通过已确认的旧版控制入口停止、启动 adbd，核对 `id` 为 uid2000(shell)，最后停止 ADB 并检查端口明确拒绝连接。这个过程只重启调试服务，不重启电视。

使用已定义的 [Send-LegacyTclCommand](../../docs/installation.md) 时：

```powershell
adb -s "<电视IP>:5555" shell setprop service.adb.root 0
Send-LegacyTclCommand -TvAddress '<电视IP>' -Command 'stop adbd'
Send-LegacyTclCommand -TvAddress '<电视IP>' -Command 'start adbd'
adb connect "<电视IP>:5555"
adb -s "<电视IP>:5555" shell id
# 确认 uid2000(shell) 后再停止调试服务。
Send-LegacyTclCommand -TvAddress '<电视IP>' -Command 'stop adbd'
```

不要用 `adb disconnect` 代替关闭电视端调试，也不要在尚未核对身份时宣称临时管理员权限已退出。
