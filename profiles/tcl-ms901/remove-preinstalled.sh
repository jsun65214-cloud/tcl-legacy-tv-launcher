#!/system/bin/sh
set -e
case "$(id)" in uid=0*) ;; *) echo ROOT_REQUIRED; exit 1 ;; esac
[ "$(getprop ro.product.device)" = tcl_901 ]
[ "$(getprop ro.product.board)" = BD_MST036B_D0ABIV_TCL_901 ]
[ "$(getprop ro.build.version.sdk)" = 17 ]
system_partition_ok=0
while read partition mountpoint filesystem options rest; do
    if [ "$mountpoint" = /system ] && [ "$partition" = /dev/block/mmcblk0p4 ] && [ "$filesystem" = ext4 ]; then
        system_partition_ok=1
    fi
done < /proc/mounts
[ "$system_partition_ok" = 1 ]
game=/system/app/TCL_TV_MARKET.apk
cloud=/system/app/TCL_901_708_2.70.0_201611091412_VOOLEPLAYAPK_2.5.02_GENERIC_20161108.151811.apk
vault=/system/app-disabled-20261025
[ -f "$game" ]
[ -f "$cloud" ]
[ ! -e "$vault/TCL_TV_MARKET.apk" ]
[ ! -e "$vault/TCL_901_708_2.70.0_201611091412_VOOLEPLAYAPK_2.5.02_GENERIC_20161108.151811.apk" ]
mounted=0
game_moved=0
cloud_moved=0
finish() {
    result=$?
    trap - 0
    set +e
    if [ "$result" -ne 0 ]; then
        if [ "$game_moved" = 1 ] && [ ! -e "$game" ]; then
            mv "$vault/TCL_TV_MARKET.apk" "$game" || result=74
        fi
        if [ "$cloud_moved" = 1 ] && [ ! -e "$cloud" ]; then
            mv "$vault/TCL_901_708_2.70.0_201611091412_VOOLEPLAYAPK_2.5.02_GENERIC_20161108.151811.apk" "$cloud" || result=74
        fi
        echo REMOVAL_NOT_COMPLETED_ROLLBACK_ATTEMPTED
    fi
    if [ "$mounted" = 1 ]; then
        mount -o remount,ro /dev/block/mmcblk0p4 /system || result=75
    fi
    echo TASK_EXIT="$result"
    exit "$result"
}
trap finish 0
trap 'exit 130' INT TERM HUP
am force-stop com.sxhl.tcltvmarket
am force-stop com.voole.epg
mount -o remount,rw /dev/block/mmcblk0p4 /system
mounted=1
mkdir -p "$vault"
mv "$game" "$vault/TCL_TV_MARKET.apk"
game_moved=1
mv "$cloud" "$vault/TCL_901_708_2.70.0_201611091412_VOOLEPLAYAPK_2.5.02_GENERIC_20161108.151811.apk"
cloud_moved=1
verified=0
for attempt in 1 2 3 4 5 6 7 8; do
    sleep 1
    package_list=$(pm list packages 2>&1)
    case "$package_list" in *Error*|*Exception*|*Failure*) exit 76 ;; esac
    case "$package_list" in *package:local.tv.simplehome*) ;; *) exit 76 ;; esac
    case "$package_list" in *package:com.tcl.tv*) ;; *) exit 76 ;; esac
    case "$package_list" in
        *package:com.sxhl.tcltvmarket*|*package:com.voole.epg*) ;;
        *) verified=1; break ;;
    esac
done
[ "$verified" = 1 ]
echo REMOVAL_VERIFIED
