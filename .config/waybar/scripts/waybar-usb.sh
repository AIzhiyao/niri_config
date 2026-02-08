#!/bin/bash
# 1. 寻找系统中的可移动分区 (RM=1)
# 递归搜索所有块设备，按大小降序排列，取最大的分区（避开 EFI 分区）
USB_DATA=$(lsblk -J -o NAME,RM,MOUNTPOINT,SIZE,LABEL,TYPE 2>/dev/null | \
    jq -r '[.. | objects | select(.rm == true and .type == "part")] 
    | sort_by(.size) | reverse | .[0]')

# 2. 如果完全没发现硬件
if [ "$USB_DATA" == "null" ] || [ -z "$USB_DATA" ]; then
    echo "{\"alt\": \"none\", \"tooltip\": \"未检测到 USB 设备\"}"
    exit 0
fi

# 3. 提取状态
NAME=$(echo "$USB_DATA" | jq -r '.name')
LABEL=$(echo "$USB_DATA" | jq -r '.label | select(. != null) // "未命名设备"')
MOUNT=$(echo "$USB_DATA" | jq -r '.mountpoint | select(. != null) // empty')
SIZE=$(echo "$USB_DATA" | jq -r '.size')

# 4. 根据挂载点判断状态
# 4. 根据挂载点判断状态
if [ -n "$MOUNT" ]; then
    # 已挂载：增加 "class": "mounted"
    DF_INFO=$(df -h "$MOUNT" | awk 'NR==2 {print $3, $5}')
    USED=$(echo "$DF_INFO" | awk '{print $1}')
    PERCENT=$(echo "$DF_INFO" | awk '{print $2}' | tr -d '%')
    
    echo "{\"alt\": \"mounted\", \"class\": \"mounted\", \"tooltip\": \"设备: $LABEL ($NAME)\n容量: $SIZE\n已用: $USED ($PERCENT%)\n挂载点: $MOUNT\"}"
else
    # 未挂载：增加 "class": "unmounted"
    echo "{\"alt\": \"unmounted\", \"class\": \"unmounted\", \"tooltip\": \"设备: $LABEL ($NAME)\n大小: $SIZE\n状态: 未挂载 (点击挂载)\"}"
fi