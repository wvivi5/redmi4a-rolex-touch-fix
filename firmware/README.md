# 适用固件

本补丁针对的是 **红米 4A（rolex）的 Ubuntu 24.04 镜像包**，本地包名 `上位机ubunrtu24.04`。

## 1. 版本信息

| 项 | 值 |
|---|---|
| 发行版 | Ubuntu 24.04 LTS (Noble)，aarch64 |
| 内核 | `6.14.0umeko-compile-msm89x7-rv0` |
| 引导 | lk2nd `next-ce01196-20250528` |
| 面板 | `xiaomi,rolex-hx8394f-boe`（BOE HX8394-F） |
| 触摸 | FT5336（I2C-1 `0x38`，chip id `0x53`） |
| 默认账号 | `umeko` / `1234` |
| 串口终端 | putty 连 USB 串口；或浏览器打开 `http://<手机IP>:8888` |

## 2. 固件包组成与校验值

| 文件 | 大小（字节） | SHA256 |
|---|---|---|
| `boot_rolex_fts.img`（原厂 boot.img） | 18,376,704 | `c56cf62bb70fe82bb114936368271a74a74981beef845b40ef509c5aa9a0235a` |
| `rolex/lk2nd.img` | 317,456 | `4ca42b73367a442ac8ce28685f9cd08d0db8eedaa1f4f89fb0b0ad8e90b663a8` |
| `rolex/rootfs.img` | 7,525,614,716 | `4dd5107f86b1ba57f88e9b0e8afc595d0ec7278cf436f03f0589b03ac566294c` |
| `rolex/twrp-3.3.1-0-rolex.img` | 35,446,784 | `380fff01f40de16ad3111a044d54169bc05ae9dec3b7cb74455573ef850a58ac` |
| `rolex.zip`（原包附带的分卷主包） | 966,930,180 | `d7531b5e7f466407f48fcd22314a83dff0b35d99cb5c28c5111f43a11a1ad860` |
| `rolex.z01`（原包附带的分卷第一卷） | 1,610,612,736 | `c02f948230363334891f42d39a036db4af33591986e666f15ff7614051ff1142` |

> `rolex.zip` + `rolex.z01` 是原发布包附带的同一套 image 的分卷压缩包（解压后即 `rolex/rootfs.img` 等）。
> **本仓库不提供这两个文件的下载**，列在这里只是为了方便你核对拿到的包是不是同一份。

Windows 下校验：

```bat
certutil -hashfile boot_rolex_fts.img SHA256
```

Linux 下：

```sh
sha256sum boot_rolex_fts.img
```

## 3. 本仓库 / Release 里的文件

- 仓库：说明、脚本、小体积 DTB（clone 很快）。
- Release（[v1.0.0](https://github.com/wvivi5/redmi4a-rolex-touch-fix/releases/tag/v1.0.0)）：
  修复版 `boot_rolex_fts_fixed.img`（18 MB）、整段备份 `p21_boot_fixed_19m.img`（19 MB）、修复版 DTB。
- **完整固件（`rootfs.img` 7.5 GB）不在本仓库分发**：GitHub 单文件上限 2 GB，且实测上传只有约 100 KB/s、
  下载到国内更慢。需要使用原发布渠道的 `上位机ubunrtu24.04` 包，按上面的表格校验 SHA256 即可确认是同一版本。

> 换句话说：**修复只需要换 boot.img**，rootfs 用原来的就行，不需要重新下载整包。

## 4. 官方刷机流程（原包 `说明.txt` / `flash.bat`）

原包里有 `rolex/flash.bat`，双击后按提示操作，等价于：

```bat
:: 1) 手机进入原厂 fastboot（关机后 音量- + 电源）
fastboot erase userdata
fastboot erase boot
fastboot flash boot lk2nd.img
fastboot reboot
:: 2) 手机会进入 lk2nd，lk2nd 自动进 fastboot
fastboot flash boot <选择的 boot 镜像>     :: 写在第 2 段（0x80000），不会覆盖 lk2nd
fastboot flash userdata rootfs.img
fastboot reboot
```

原包默认建议选 **带 host 的 boot 文件**（可以连下位机）；不带 host 的用于串口调试。

### 打补丁后的流程

把 `flash.bat` 里第 2 步要选的 boot 文件换成本仓库 Releases 里的
`boot_rolex_fts_fixed.img` 即可；或者机器已经装好系统时，直接：

```bat
fastboot flash boot boot_rolex_fts_fixed.img
fastboot reboot
```

## 5. 换用其它内核 / 其它镜像时

只要 boot.img 里的 DTB 仍然写 `edt,edt-ft5336`，触摸就不会工作。用仓库脚本可以先检查再决定：

```bat
python tools\patch_boot_dtb.py 新的boot.img check
```

- 输出「未修复」→ `python tools\patch_boot_dtb.py 新的boot.img` 打补丁后再刷；
- 输出「已修复」→ 不用动；
- 输出「未找到触摸节点字符串」→ 说明这份 DTB 结构不同（例如触摸节点是 GT911），需要单独分析，不能直接套用本仓库的镜像。

## 6. 已知与触摸无关的问题（记录备查）

- **WiFi（wcn36xx）极不稳定**：实测丢包 50%、速度约 1 KB/s，SFTP / HTTP 传大文件基本不可用。
  应急可走 **USB CDC-ACM 串口**（PC 侧 COMx，手机侧 `/dev/ttyGS0`），
  传输前 `systemctl stop autottyGS0`，并把串口设为 raw（关闭 `OPOST`），实测约 1.1 MB/s。
- 重启前后 eMMC 编号会在 `mmcblk0` / `mmcblk1` 之间变化，脚本不要写死分区号。
- 系统自带的 Debian 内核包 `/usr/lib/linux-image-…/qcom/msm8917-xiaomi-rolex.dtb` 里
  触摸是 **GT911（0x5d，disabled）**，和 boot.img 里实际生效的 DTB（FT5336@0x38，enabled）
  **不是同一份**，不要拿它当参考去改。
