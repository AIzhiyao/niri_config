#!/bin/bash

DEV_NAME=$(lsblk -ln -o NAME,RM,TYPE,SIZE,LABEL | \
    grep -iv "EFI" | \
    awk '$2=="1" && $3=="part" {print $1, $4}' | \
    sort -h -k2 -r | \
    head -n1 | \
    awk '{print $1}')

# 使用字符串检查代替整数对比，防止脚本报错
if [ -z "$DEV_NAME" ] || [ "$DEV_NAME" == "null" ]; then
    exit 0
fi

DEV_PATH="/dev/$DEV_NAME"

case "$1" in
    "open")
        MOUNT_PATH=$(lsblk -no MOUNTPOINT "$DEV_PATH" | head -n 1 | xargs)
        # 获取挂载路径
        if [ -n "$MOUNT_PATH" ] && [ "$MOUNT_PATH" != "null" ]; then
            # 状态：已挂载 -> 直接打开
            xdg-open "$MOUNT_PATH"
        else
            # 状态：未挂载 -> 弹出提示，不进行挂载操作
            notify-send -u normal "USB 设备" "设备尚未挂载，请先挂载后再打开。" \
                --icon=drive-removable-media
        fi
        ;;
    "unmount")
        # 卸载并切断电源（弹出）
        udisksctl unmount -b "$DEV_PATH" && udisksctl power-off -b "$DEV_PATH"
        ;;
esac