# boot 镜像说明

镜像文件放在 **[Releases](https://github.com/wvivi5/redmi4a-rolex-touch-fix/releases/tag/v1.0.0)** 里（单个 18–19 MB，避免仓库变大）。

| 文件 | 大小 | SHA256 | 用途 |
|---|---|---|---|
| `boot_rolex_fts_fixed.img` | 18,376,704 B | `0ed76c58289b3aaabe553c7768fc0c0db23e81b30fbe7daf0efb876fc679c813` | **首选**。修复版 boot.img，在 **lk2nd fastboot** 里 `fastboot flash boot` |
| `p21_boot_fixed_19m.img` | 19,922,944 B | `5cbf9ff42ab2a926207c9b744654b1d0cf9080fc7e04fef23ee7a17f8ca8800f` | boot 分区**前 19 MB 整段**（lk2nd + 修复版 boot.img），仅在**原厂 aboot fastboot** 下整段恢复用 |

原厂 `boot_rolex_fts.img`（18,376,704 B，`c56cf62bb70fe82bb114936368271a74a74981beef845b40ef509c5aa9a0235a`）
与本修复版只差 **1 个字节**（偏移 `8977682`，`0x33`→`0x30`，即 `ft5336`→`ft5306`）。

## 为什么有两种刷法

这台机器的 boot 分区布局是：

```
偏移 0x000000  lk2nd 引导（312 KB）
偏移 0x080000  Ubuntu boot.img（kernel + 追加的 DTB + initrd）
```

- **lk2nd 的 fastboot**：`fastboot flash boot <img>` 会写到 `0x80000`，保留 lk2nd 自身 → 用 `boot_rolex_fts_fixed.img`。
- **原厂 aboot 的 fastboot**（关机后 音量− + 电源）：从 `0x0` 开始整段写 → 用 `p21_boot_fixed_19m.img`（或者固件包里的 `lk2nd.img`）。

> 在 lk2nd fastboot 下千万不要刷 `p21_boot_fixed_19m.img`，会错位到 `0x80000`。
> 在 aboot fastboot 下刷 `boot_rolex_fts_fixed.img` 会覆盖掉 lk2nd 的开头，需要再补刷 `lk2nd.img`。
