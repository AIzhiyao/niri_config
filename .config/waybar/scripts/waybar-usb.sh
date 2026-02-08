#!/bin/bash

# 方法1：检测可移动设备（RM=1）
detect_method_1() {
    # 逻辑：递归查找所有 blockdevices，匹配 rm=true 且 type=part 的分区
    # 并根据大小排序，取最大的那个分区（防止显示 Ventoy 的 EFI 小分区）
    lsblk -J -o NAME,TYPE,MOUNTPOINT,SIZE,LABEL,RM 2>/dev/null | \
        jq -r '.. | objects | select(.rm == true and .type == "part")' 2>/dev/null | \
        jq -s 'sort_by(.size) | reverse | .[0]' 2>/dev/null
}

# 方法2：检查/run/media 目录
detect_method_2() {
    # 查找 /run/media/*
    for mount_base in  /run/media; do
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

# # 尝试各种检测方法
usb_info=$(detect_method_1)

if [ -z "$usb_info" ] || [ "$usb_info" = "null" ]; then
    usb_info=$(detect_method_2)
fi

# 如果检测不到
if [ -z "$usb_info" ] || [ "$usb_info" = "null" ]; then
    echo "{\"alt\":\"none\",\"tooltip\":\"未检测到 USB 设备\",\"class\":\"none\"}"
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
        echo "{\"alt\":\"mounted\",\"tooltip\":\"${tooltip}\",\"class\":\"mounted\",\"percentage\":${usage}}"
    else
        tooltip="设备: ${display_name}\\n大小: ${size}\\n挂载点: ${mountpoint}"
        echo "{\"alt\":\"mounted\",\"tooltip\":\"${tooltip}\",\"class\":\"mounted\"}"
    fi
else
    # 未挂载
    tooltip="设备: ${display_name}\\n大小: ${size}\\n状态: 未挂载"
    echo "{\"alt\":\"unmounted\",\"tooltip\":\"${tooltip}\",\"class\":\"unmounted\"}"
fi