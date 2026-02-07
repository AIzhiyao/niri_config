#!/bin/bash

# 图标定义
ICON_MOUNTED="󰐷"
ICON_UNMOUNTED="󰙄"
ICON_NONE="󱊟"

# 方法1：检测可移动设备（RM=1）
detect_method_1() {
    lsblk -J -o NAME,TYPE,MOUNTPOINT,SIZE,LABEL,RM 2>/dev/null | \
        jq -r '.blockdevices[] | select(.rm == true and .type == "part") | {name: .name, mountpoint: .mountpoint, size: .size, label: .label}' 2>/dev/null | \
        jq -s '.[0]' 2>/dev/null
}

# 方法2：检测 /dev/sd* 设备（排除主硬盘）
detect_method_2() {
    # 获取主硬盘设备（通常是 sda）
    root_disk=$(lsblk -no PKNAME $(findmnt -n -o SOURCE /) 2>/dev/null)
    
    # 查找所有 sd* 设备，排除主硬盘
    for dev in /sys/block/sd*; do
        [ -e "$dev" ] || continue
        devname=$(basename "$dev")
        
        # 跳过主硬盘
        [ "$devname" = "$root_disk" ] && continue
        
        # 检查是否是可移动设备
        if [ -f "$dev/removable" ] && [ "$(cat $dev/removable)" = "1" ]; then
            # 查找第一个分区
            for part in /sys/block/$devname/${devname}*; do
                [ -e "$part" ] || continue
                partname=$(basename "$part")
                
                # 获取信息
                size=$(lsblk -no SIZE /dev/$partname 2>/dev/null)
                label=$(lsblk -no LABEL /dev/$partname 2>/dev/null)
                mountpoint=$(lsblk -no MOUNTPOINT /dev/$partname 2>/dev/null)
                
                echo "{\"name\":\"$partname\",\"mountpoint\":\"$mountpoint\",\"size\":\"$size\",\"label\":\"$label\"}"
                return
            done
        fi
    done
    echo "null"
}

# 方法3：检查 /media 和 /run/media 目录
detect_method_3() {
    # 查找 /media/* 或 /run/media/*
    for mount_base in /media /run/media; do
        if [ -d "$mount_base" ]; then
            for userdir in "$mount_base"/*; do
                [ -d "$userdir" ] || continue
                for mount in "$userdir"/*; do
                    [ -d "$mount" ] || continue
                    
                    # 获取设备信息
                    device=$(findmnt -n -o SOURCE "$mount" 2>/dev/null)
                    if [ -n "$device" ]; then
                        devname=$(basename "$device")
                        size=$(lsblk -no SIZE "$device" 2>/dev/null)
                        label=$(basename "$mount")
                        
                        echo "{\"name\":\"$devname\",\"mountpoint\":\"$mount\",\"size\":\"$size\",\"label\":\"$label\"}"
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
    usb_info=$(detect_method_3)
fi

# 如果还是检测不到
if [ -z "$usb_info" ] || [ "$usb_info" = "null" ]; then
    echo "{\"text\":\"${ICON_NONE}\",\"alt\":\"none\",\"tooltip\":\"未检测到 USB 设备\",\"class\":\"none\"}"
    exit 0
fi

# 提取设备信息
device_name=$(echo "$usb_info" | jq -r '.name // empty')
mountpoint=$(echo "$usb_info" | jq -r '.mountpoint // empty')
size=$(echo "$usb_info" | jq -r '.size // empty')
label=$(echo "$usb_info" | jq -r '.label // empty')

# 使用标签或设备名称
if [ -n "$label" ] && [ "$label" != "null" ]; then
    display_name="$label"
else
    display_name="$device_name"
fi

if [ -n "$mountpoint" ] && [ "$mountpoint" != "null" ]; then
    # 已挂载 - 获取使用信息
    df_output=$(df -h "$mountpoint" 2>/dev/null | awk 'NR==2 {print $3, $5}')
    if [ -n "$df_output" ]; then
        used=$(echo "$df_output" | awk '{print $1}')
        usage=$(echo "$df_output" | awk '{print $2}' | tr -d '%')
        tooltip="设备: ${display_name}\\n大小: ${size}\\n挂载点: ${mountpoint}\\n已用: ${used} (${usage}%)"
        echo "{\"text\":\"${ICON_MOUNTED} ${display_name}\",\"alt\":\"mounted\",\"tooltip\":\"${tooltip}\",\"class\":\"mounted\",\"percentage\":${usage}}"
    else
        tooltip="设备: ${display_name}\\n大小: ${size}\\n挂载点: ${mountpoint}"
        echo "{\"text\":\"${ICON_MOUNTED} ${display_name}\",\"alt\":\"mounted\",\"tooltip\":\"${tooltip}\",\"class\":\"mounted\"}"
    fi
else
    # 未挂载
    tooltip="设备: ${display_name}\\n大小: ${size}\\n状态: 未挂载"
    echo "{\"text\":\"${ICON_UNMOUNTED} ${display_name}\",\"alt\":\"unmounted\",\"tooltip\":\"${tooltip}\",\"class\":\"unmounted\"}"
fi