#!/bin/sh
# 红米 4A (rolex) Ubuntu 触摸状态自检
# 在手机上的 Ubuntu 里直接运行： sh check_touch.sh

echo "=== 1. 驱动绑定 ==="
if [ -L /sys/bus/i2c/devices/1-0038/driver ]; then
    echo "OK   $(readlink -f /sys/bus/i2c/devices/1-0038/driver)"
else
    echo "FAIL 1-0038 未绑定驱动（触摸多半不可用）"
fi

echo
echo "=== 2. 输入设备 ==="
if grep -q ft5x06 /proc/bus/input/devices; then
    grep -B1 -A5 ft5x06 /proc/bus/input/devices
else
    echo "FAIL 没有 ft5x06 输入设备"
fi

echo
echo "=== 3. 触摸供电 L10 ==="
if [ -r /sys/kernel/debug/regulator/regulator_summary ]; then
    grep -E '^ *l10 ' /sys/kernel/debug/regulator/regulator_summary
else
    sudo grep -E '^ *l10 ' /sys/kernel/debug/regulator/regulator_summary 2>/dev/null \
        || echo "（需要 root 或 debugfs 未挂载；可忽略）"
fi

echo
echo "=== 4. 内核日志 ==="
sudo dmesg 2>/dev/null | grep -i ft5 || echo "（无 ft5 相关日志）"

echo
echo "=== 5. 触摸事件测试（10 秒，点几下屏幕）==="
DEV=$(grep -A5 ft5x06 /proc/bus/input/devices | sed -n 's/.*Handlers=\(event[0-9]*\).*/\1/p' | head -1)
if [ -n "$DEV" ]; then
    echo "读取 /dev/input/$DEV ..."
    sudo timeout 10 cat "/dev/input/$DEV" > /tmp/_touchtest.bin 2>/dev/null
    SZ=$(stat -c %s /tmp/_touchtest.bin 2>/dev/null || echo 0)
    if [ "$SZ" -gt 0 ]; then
        echo "OK   收到 $SZ 字节触摸事件"
    else
        echo "FAIL 10 秒内没有收到事件（这段时间有触摸屏幕吗？）"
    fi
else
    echo "FAIL 找不到触摸事件节点"
fi
