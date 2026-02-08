#!/bin/bash
# 寻找系统中的可移动分区 (RM=1)
USB_DATA=$(lsblk -J -b -o NAME,RM,MOUNTPOINT,SIZE,LABEL,TYPE 2>/dev/null | \
    jq -r '[.. | objects | select(.rm == true and .type == "part" and (.label | test("EFI"; "i") | not))] 
    | sort_by(.size | tonumber) | reverse | .[0]')

if [ "$USB_DATA" == "null" ] || [ -z "$USB_DATA" ]; then
    echo "{\"alt\": \"none\", \"tooltip\": \"未检测到 USB 设备\"}"
    exit 0
fi

# 提取状态
NAME=$(echo "$USB_DATA" | jq -r '.name')
LABEL=$(echo "$USB_DATA" | jq -r '.label | select(. != null) // "未命名设备"')
MOUNT=$(echo "$USB_DATA" | jq -r '.mountpoint | select(. != null) // empty')
SIZE=$(echo "$USB_DATA" | jq -r '.size')
# MOUNT=$(lsblk -no MOUNTPOINT "/dev/$NAME" | xargs)

# 4. 根据挂载点判断状态
if [ -n "$MOUNT" ]; then
    # 已挂载：增加 "class": "mounted"
    DF_INFO=$(df -h "$MOUNT" | awk 'NR==2 {print $3, $5}')
    USED=$(echo "$DF_INFO" | awk '{print $1}')
    PERCENT=$(echo "$DF_INFO" | awk '{print $2}' | tr -d '%')
    
    echo "{\"alt\": \"mounted\", \"class\": \"mounted\", \"tooltip\": \"设备: $LABEL ($NAME)\n容量: $SIZE\n已用: $USED ($PERCENT%)\n挂载点: $MOUNT\"}"
else
    # 未挂载：增加 "class": "power-off"
    echo "{\"alt\": \"power-off\", \"class\": \"power-off\", \"tooltip\": \"设备: $LABEL ($NAME)\n大小: $SIZE\n状态: 已弹出\"}"
fi