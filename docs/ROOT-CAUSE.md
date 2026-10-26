# 取证与定位全过程

日期：2026-10-25
设备：Xiaomi Redmi 4A（rolex，MSM8917 / SD425），序列号 `5104c6f51f404`
系统：Ubuntu 24.04（`6.14.0umeko-compile-msm89x7-rv0`），lk2nd `next-ce01196-20250528`
面板：`xiaomi,rolex-hx8394f-boe`（BOE HX8394-F）

---

## 1. 系统里没有触摸输入设备

```
$ cat /proc/bus/input/devices
... pm8941_pwrkey / pm8941_resin / gpio-keys / gpio-vibrator / Headset Jack
（没有触摸）
```

## 2. 设备树节点是 enabled 的，客户端也创建了

```
$ cat /proc/device-tree/soc@0/i2c@78b7000/touchscreen@38/compatible | tr '\0' ' '
edt,edt-ft5336 edt,edt-ft5x06
$ cat .../status
okay
$ ls /sys/bus/i2c/devices/ | grep 0038
1-0038
```

I2C 客户端 `1-0038` 存在，但**没有 `driver` 软链接**（未绑定任何驱动）。

## 3. 驱动支持表里没有 ft5336

```
$ modinfo edt_ft5x06 | grep -i '^alias'
alias: i2c:edt-ft5x06
alias: of:N*T*Cedt,edt-ft5206C*
alias: of:N*T*Cedt,edt-ft5206
alias: of:N*T*Cedt,edt-ft5306C*
alias: of:N*T*Cedt,edt-ft5306
alias: of:N*T*Cedt,edt-ft5406C*
...
（没有 edt,edt-ft5336，也没有 of:N*T*Cedt,edt-ft5x06）
```

OF 设备的匹配优先用 `of_match_table`，匹配失败后才会尝试 i2c id 表，而该设备的 i2c client name 来自节点名（`touchscreen`），也对不上。
**所以 probe 一次都没执行** —— 这解释了为什么 dmesg 里连报错都没有。

## 4. 因为没 probe，触摸供电一直没开

```
$ grep -E '^ *(l5|l10) ' /sys/kernel/debug/regulator/regulator_summary
    l5   0 0 0 idle 1800mV
    l10  0 0 0 idle 2800mV      <-- 触摸 vcc，use=0

$ i2ctransfer -y 1 w1@0x38 0xa3 r2
Error: Sending messages failed: No such device or address   (NAK)
```

DT 里 `vcc-supply = <&pm8916_l10>`、`iovcc-supply = <&pm8916_l5>`，驱动 probe 时才会 enable；没 probe → 芯片没电 → I2C 全部 NAK。

## 5. 修复后

```
$ ls -l /sys/bus/i2c/devices/1-0038/driver
... -> ../../../../../../bus/i2c/drivers/edt_ft5x06

$ dmesg | grep -i ft5
input: generic ft5x06 (53) as /devices/platform/soc@0/78b7000.i2c/i2c-1/1-0038/input/input4

$ grep -E '^ *l10 ' /sys/kernel/debug/regulator/regulator_summary
    l10  1 1 0 unknown 2800mV      <-- use=1
```

chip id `0x53` 说明硬件就是 FT5336，DTS 里型号没写错，**错的是 compatible 字符串**。

---

## 6. 镜像结构与精确偏移

boot 分区 = `/dev/mmcblk0p21`（GPT 标签 `boot`，64 MB；重启前后编号可能在 `mmcblk0` / `mmcblk1` 之间变化）。

| 分区偏移 | 十六进制 | 内容 |
|---|---|---|
| `0` | `0x0` | lk2nd 引导镜像（`ANDROID!`，kernel 311,916 B，cmdline = `lk2nd`） |
| `524288` | `0x80000` | Ubuntu 的 boot.img（`ANDROID!`，kernel 8,991,359 B + initrd 9,380,590 B，cmdline = `console=tty0 root=UUID=93afcbbe-… splash`） |
| `9469202` | `0x907D12` | 追加在 kernel 末尾的 DTB（48,493 B，魔数 `d0 0d fe ed`） |
| `9501958` | `0x90FD06` | DTB 字符串表中的 `edt,edt-ft5336`（14 B） |

在独立的 `boot.img` 文件里（从 `0x80000` 开始），对应偏移为：

| boot.img 内偏移 | 内容 |
|---|---|
| `8977670` | `edt,edt-ft5336` |
| `8977682` | 唯一不同的那个字节（`0x33` → `0x30`） |

## 7. 为什么 lk2nd 不影响触摸

lk2nd 启动时只做一件事：根据检测到的面板改写面板节点的 `compatible`
（`xiaomi,rolex-panel` → `xiaomi,rolex-hx8394f-boe\0xiaomi,rolex-panel`，所以运行中的 DTB 从 48,493 B 变成 48,915 B），
并只对 `touchscreen-compatible` 匹配的节点清 `status`。这套 Ubuntu 的 DTB 里只有 FT5336 节点，lk2nd 不会碰它。

## 8. 验证补丁是否已生效（离线，不解包）

```python
data = open("boot_rolex_fts.img", "rb").read()
print(data.count(b"edt,edt-ft5336"), data.count(b"edt,edt-ft5306"))
```

或用仓库里的 `tools/patch_boot_dtb.py xxx.img check`。

## 9. 本次踩到的其他坑（与触摸无关，记录备查）

- 重启前后 eMMC 编号会从 `mmcblk1` 变 `mmcblk0`，脚本里别写死。
- 该机器 WiFi（wcn36xx）当时丢包 50%、速度 1 KB/s，`python -m http.server` / SFTP 拉大文件会卡在几十 KB；
  最后走 **USB CDC-ACM**（Windows 显示 COM30，设备端 `/dev/ttyGS0`）：
  先 `systemctl stop autottyGS0`，用 termios 设成 raw（关键是关掉 `OPOST`），1.1 MB/s 稳定拉完并 SHA256 校验一致。
- `/dev/ttyGS0` 的属主会在 `umeko` 与 `root:tty` 之间变化，写文件用 `sudo` 更稳。
