#!/bin/bash

# 获取当前第一个可移动分区的设备名 (如 sda1)
DEV_NAME=$(lsblk -J -o NAME,RM,TYPE 2>/dev/null | \
    jq -r '[.. | objects | select(.rm == true and .type == "part")] | sort_by(.size) | reverse | .[0].name')

[ -z "$DEV_NAME" ] && exit 0
DEV_PATH="/dev/$DEV_NAME"

case "$1" in
    "open")
        # 如果未挂载则尝试挂载
        udisksctl mount -b "$DEV_PATH" 2>/dev/null
        # 获取挂载路径
        MOUNT_PATH=$(lsblk -no MOUNTPOINT "$DEV_PATH" | head -n 1)
        # 使用默认管理器打开
        if [ -n "$MOUNT_PATH" ]; then
            xdg-open "$MOUNT_PATH" &
        fi
        pkill -RTMIN+8 waybar
        ;;
    "unmount")
        # 卸载并切断电源（弹出）
        # udiskie 会捕获到此动作并发送系统通知
        if udisksctl unmount -b "$DEV_PATH" && udisksctl power-off -b "$DEV_PATH"; then
            # 卸载成功后，等一点点时间让内核释放设备，然后通知 Waybar 刷新
            (sleep 0.5 && pkill -RTMIN+8 waybar) &
        fi
        ;;
esac