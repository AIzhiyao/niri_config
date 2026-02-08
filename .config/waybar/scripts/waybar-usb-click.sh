#!/bin/bash

ACTION="$1"

# 方法1：检测可移动设备（RM=1）
detect_method_1() {
    # 逻辑：递归查找所有 blockdevices，匹配 rm=true 且 type=part 的分区
    # 并根据大小排序，取最大的那个分区（防止显示 Ventoy 的 EFI 小分区）
    lsblk -J -o NAME,TYPE,MOUNTPOINT,SIZE,LABEL,RM 2>/dev/null | \
        jq -r '.. | objects | select(.rm == true and .type == "part")' 2>/dev/null | \
        jq -s 'sort_by(.size) | reverse | .[0]' 2>/dev/null
}

# 方法2：检查已挂载的设备
detect_method_2() {
    for mount_base in /run/media; do
        if [ -d "$mount_base" ]; then
            for userdir in "$mount_base"/*; do
                [ -d "$userdir" ] || continue
                for mount in "$userdir"/*; do
                    [ -d "$mount" ] || continue
                    
                    device=$(findmnt -n -o SOURCE "$mount" 2>/dev/null)
                    if [ -n "$device" ]; then
                        devname=$(basename "$device")
                        echo "{\"name\":\"$devname\",\"mountpoint\":\"$mount\"}"
                        return
                    fi
                done
            done
        fi
    done
    echo "null"
}

# 尝试各种检测方法
usb_info=$(detect_method_1)

if [ -z "$usb_info" ] || [ "$usb_info" = "null" ]; then
    usb_info=$(detect_method_2)
fi

if [ -z "$usb_info" ] || [ "$usb_info" = "null" ]; then
    notify-send "USB 管理器" "未检测到 USB 设备" -i drive-removable-media
    exit 1
fi

device_name=$(echo "$usb_info" | jq -r '.name // empty')
mountpoint=$(echo "$usb_info" | jq -r '.mountpoint // empty')
device_path="/dev/$device_name"

case "$ACTION" in
    "open")
        # 如果未挂载，先挂载
        if [ -z "$mountpoint" ] || [ "$mountpoint" = "null" ]; then
            mount_output=$(udisksctl mount -b "$device_path" 2>&1)
            if [ $? -eq 0 ]; then
                mountpoint=$(echo "$mount_output" | grep -oP 'at \K.*' | tr -d '.')
                notify-send "USB 管理器" "已挂载到 $mountpoint" -i drive-removable-media
                sleep 0.5
            else
                notify-send "USB 管理器" "挂载失败: $mount_output" -i dialog-error
                exit 1
            fi
        fi
        
        # 使用 yazi 打开文件管理器
        if command -v foot &> /dev/null; then
            nohup foot -e yazi "$mountpoint" > /dev/null 2>&1 &
        elif command -v kitty &> /dev/null; then
            nohup kitty -e yazi "$mountpoint" > /dev/null 2>&1 &
        elif command -v alacritty &> /dev/null; then
            nohup alacritty -e yazi "$mountpoint" > /dev/null 2>&1 &
        else
            notify-send "USB 管理器" "未找到合适的终端模拟器 (foot/kitty/alacritty)" -i dialog-error
        fi
        ;;
        
    "unmount")
        if [ -z "$mountpoint" ] || [ "$mountpoint" = "null" ]; then
            notify-send "USB 管理器" "设备未挂载" -i drive-removable-media
            exit 0
        fi
        
        # 卸载设备
        unmount_output=$(udisksctl unmount -b "$device_path" 2>&1)
        if [ $? -eq 0 ]; then
            notify-send "USB 管理器" "已安全卸载 USB 设备" -i drive-removable-media
            
            # 可选：弹出设备（物理断电）
            # udisksctl power-off -b "$device_path"
        else
            notify-send "USB 管理器" "卸载失败: $unmount_output" -i dialog-error
        fi
        ;;
        
    *)
        echo "用法: $0 {open|unmount}"
        exit 1
        ;;
esac