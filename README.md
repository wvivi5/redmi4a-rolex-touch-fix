# 红米 4A (rolex) Ubuntu 24.04 触摸修复包

[![Release](https://img.shields.io/github/v/release/wvivi5/redmi4a-rolex-touch-fix)](https://github.com/wvivi5/redmi4a-rolex-touch-fix/releases/latest)

> Xiaomi Redmi 4A (MSM8917 / SD425, codename **rolex**) 刷 Ubuntu 24.04 后**触摸屏完全无反应**的修复。
> 根因是 boot.img 里 DTB 的触摸节点 `compatible` 字符串写了一个内核不认识的型号名 —— 改 **1 个字节**即可。
>
> Touch fix for Xiaomi Redmi 4A (rolex) running Ubuntu 24.04. The touchscreen node in the DTB
> appended to the kernel uses `compatible = "edt,edt-ft5336"`, which no kernel driver matches.
> One byte change (`ft5336` → `ft5306`) makes the `edt_ft5x06` driver bind and the panel come alive.

> 另：**postmarketOS** 上的同类问题（lk2nd 只认 GT911、与 FT5336 共用 GPIO）修法完全不同，
> 见 [redmi4a-rolex-pmos-touch-fix](https://github.com/wvivi5/redmi4a-rolex-pmos-touch-fix)。

---

## 1. 症状

- 系统能正常启动、显示正常，但**屏幕怎么点都没反应**，没有任何输入设备。
- `dmesg | grep -i ft5` 没有任何输出（连报错都没有）。
- `/proc/bus/input/devices` 里没有触摸设备。
- `i2cdetect` / `i2ctransfer` 访问 I2C-1 的 `0x38` 全部返回 NAK（`No such device or address`）。

## 2. 根因

| 项 | 实际情况 |
|---|---|
| 触摸芯片 | **FT5336**（修好后驱动读出的 chip id = `0x53`），I2C-1 地址 `0x38` |
| 内核驱动 | `edt_ft5x06.ko`，正常存在、正常加载 |
| 设备树节点 | `touchscreen@38`，`status = "okay"`，`compatible = "edt,edt-ft5336", "edt,edt-ft5x06"` |
| 驱动 `of_match` 表 | 只有 `edt,edt-ft5206` / `ft5306` / `ft5406` / `ft5506`，以及 `focaltech,ft6236/5426/5452/8201/8719`、`evervision,ev-ft5726`；**没有 `ft5336`，也没有通用的 `ft5x06`** |
| 结果 | 设备与驱动匹配失败 → **probe 函数根本不执行**（所以 dmesg 连一条错误都没有）→ PM8916 **L10（触摸 2.8V）永远不打开** → I2C 0x38 无应答 |

一句话：**不是没驱动、不是没上电、不是 lk2nd 的锅，是 DTS 里写了一个驱动不认识的 compatible。**

修好后：

```
input: generic ft5x06 (53) as /devices/platform/soc@0/78b7000.i2c/i2c-1/1-0038/input/input4
```

`/dev/input/event4` 即触摸屏，`regulator_summary` 里 L10 从 `use=0` 变为 `use=1`。

## 3. 修复内容

DTB 字符串表里等长替换（14 字节，DTB 大小/偏移/结构完全不变）：

```
edt,edt-ft5336   ->   edt,edt-ft5306
```

在 `boot.img` 里只有 **1 个字节**不同（`3` → `0`）：

| | `boot_rolex_fts.img`（原厂） | `boot_rolex_fts_fixed.img`（修复） |
|---|---|---|
| 大小 | 18,376,704 B | 18,376,704 B |
| SHA256 | `c56cf62bb70fe82bb114936368271a74a74981beef845b40ef509c5aa9a0235a` | `0ed76c58289b3aaabe553c7768fc0c0db23e81b30fbe7daf0efb876fc679c813` |
| 差异 | — | 偏移 `8977682`：`0x33`(`3`) → `0x30`(`0`) |

## 4. 下载

镜像文件在 **Releases** 里（单文件 18–19 MB，避免把仓库撑大）：

**https://github.com/wvivi5/redmi4a-rolex-touch-fix/releases/tag/v1.0.0**

| 文件 | 大小 | SHA256 | 说明 |
|---|---|---|---|
| `boot_rolex_fts_fixed.img` | 18,376,704 B | `0ed76c58289b3aaabe553c7768fc0c0db23e81b30fbe7daf0efb876fc679c813` | **修复版 boot.img**，在 **lk2nd 的 fastboot** 里刷入（相当于官方 `flash.bat` 第 2 步选择 boot 文件） |
| `p21_boot_fixed_19m.img` | 19,922,944 B | `5cbf9ff42ab2a926207c9b744654b1d0cf9080fc7e04fef23ee7a17f8ca8800f` | boot **分区前 19 MB 整段镜像**（含 lk2nd + 修复版 boot.img），整段恢复用 |
| `msm8917-xiaomi-rolex-fixed.dtb` | 48,493 B | — | 从镜像中摘出的修复版 DTB，可用 `dtc` 反编译对照 |

仓库内文件：

| 路径 | 说明 |
|---|---|
| `dtb/msm8917-xiaomi-rolex-fixed.dtb` | 修复版 DTB（48,493 B） |
| `boot/README.md` | 两个 boot 镜像的区别与刷法注意事项 |
| `tools/patch_boot_dtb.py` | 给任意 boot.img 打补丁 / 还原 / 检查（自动备份） |
| `tools/flash_fixed_boot.bat` | Windows 一键刷入（需手机处于 fastboot） |
| `tools/check_touch.sh` | 在手机（Ubuntu）上验证触摸是否正常 |
| `firmware/README.md` | 适用固件的版本、组成、校验值与官方刷机流程 |
| `docs/ROOT-CAUSE.md` | 完整取证记录（偏移、命令、日志） |

## 5. 刷入方法

### 5.1 推荐：lk2nd fastboot 刷 boot.img

与固件自带的 `flash.bat` 流程一致（先刷 `lk2nd.img`，进入 lk2nd 后再刷 boot / rootfs）。
**在 lk2nd 的 fastboot 里 `fastboot flash boot` 只会写 boot.img 区段，不会破坏 lk2nd 自身。**

1. 从 [Releases](https://github.com/wvivi5/redmi4a-rolex-touch-fix/releases/tag/v1.0.0) 下载 `boot_rolex_fts_fixed.img`；
2. 手机进入 fastboot（lk2nd）后执行：

```bat
fastboot devices
fastboot flash boot boot_rolex_fts_fixed.img
fastboot reboot
```

Windows 下也可以把 `boot_rolex_fts_fixed.img` 放在 `tools\` 目录里，双击 `tools\flash_fixed_boot.bat`。

### 5.2 整段恢复（可选，19 MB 镜像）

仅当你想把 boot 分区**前 19 MB 整体**恢复成“lk2nd + 修复版 boot.img”时使用。
需要在 **aboot（原厂）fastboot** 下（关机后 音量− + 电源），此时 `fastboot flash boot` 从分区偏移 0 开始写入：

```bat
fastboot flash boot p21_boot_fixed_19m.img
fastboot reboot
```

> ⚠️ 不要把这 19 MB 镜像刷进 lk2nd 的 fastboot —— lk2nd 会把它写到偏移 `0x80000`，导致镜像错位。
> 在 lk2nd fastboot 下请只用 `boot_rolex_fts_fixed.img`。

## 6. 验证

手机（Ubuntu）上执行：

```sh
# 驱动绑定
ls -l /sys/bus/i2c/devices/1-0038/driver        # -> .../drivers/edt_ft5x06
# 输入设备
grep -A3 ft5x06 /proc/bus/input/devices         # Name="generic ft5x06 (53)"，Handlers=event4
# 触摸供电
sudo grep -E '^ *l10 ' /sys/kernel/debug/regulator/regulator_summary   # use=1
# 日志
sudo dmesg | grep -i ft5
```

或直接运行 `tools/check_touch.sh`。重启后依然有效（已验证）。

## 7. 还原

```bat
python tools/patch_boot_dtb.py boot_rolex_fts_fixed.img revert
```

会生成 `boot_rolex_fts_fixed.img.orig`（首次打补丁时的自动备份），或者直接改回：

```
edt,edt-ft5306  ->  edt,edt-ft5336
```

也可以直接从固件包里拿原厂 `boot_rolex_fts.img`（SHA256 `c56cf62b…a0235a`）刷回去。

## 8. 适用固件

适用于 **本地固件包 `上位机ubunrtu24.04`**（Ubuntu 24.04 for rolex）：

- 内核：`6.14.0umeko-compile-msm89x7-rv0`（aarch64）
- 引导：lk2nd `next-ce01196-20250528`
- 系统：Ubuntu 24.04 LTS (Noble)，用户名 `umeko`，密码 `1234`
- 组成与校验值见 [`firmware/README.md`](firmware/README.md)
- 本仓库与 Release **只分发修复用的 boot 镜像**（18 MB + 19 MB）和 DTB；完整 `rootfs.img`（7.5 GB）体积太大，不在 GitHub 分发
- 固件组成、大小与 SHA256 清单见 [`firmware/README.md`](firmware/README.md)，可用来核对原渠道固件包是不是同一版本

判断你的 boot.img 是否需要这个补丁：

```bat
python tools/patch_boot_dtb.py 你的boot.img check
```

输出 `'edt,edt-ft5336' 出现 1 次` + `未修复` → 需要；输出 `已修复` → 已经修好。

## 9. 会复发的情况

- **重刷同一份原厂固件（含原 boot.img）→ 立刻复发**。
- 长期修法：改内核源码 DTS 后重新编译：

  ```dts
  /* arch/arm64/boot/dts/qcom/msm8917-xiaomi-rolex.dts */
  touchscreen@38 {
      compatible = "edt,edt-ft5306";
      ...
  };
  ```

  再重新打包 boot.img（`cat Image.gz dtb > kernel` + mkbootimg）。
- 注意：系统里安装的 Debian 内核包自带 DTB
  `/usr/lib/linux-image-6.14.0umeko-compile-msm89x7-rv0/qcom/msm8917-xiaomi-rolex.dtb`
  里是 **GT911（0x5d, disabled）**，与 boot.img 实际使用的 DTB（FT5336@0x38, enabled）**不是同一份**，维护时别拿错。
- pmOS 官方 Wiki 上那套改 lk2nd DTS、`edt-ft5306` 的补丁是给 pmOS 用的；这套 Ubuntu 的 DTB 已经 append 在 kernel 里，**不需要动 lk2nd**。

## 10. 取证摘要

见 [`docs/ROOT-CAUSE.md`](docs/ROOT-CAUSE.md)。

## 免责声明

刷机有风险，请自行确认机型（rolex，Redmi 4A）与固件版本。仓库与 Release 里的镜像均从实测可用的机器上导出，并附 SHA256 校验。

## License

MIT
