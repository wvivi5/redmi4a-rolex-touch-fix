#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""红米 4A (rolex) boot.img DTB 触摸 compatible 修正 / 还原 / 检查

问题：boot.img 的 kernel 末尾追加的 DTB 里，FT5336 触摸节点写成
      compatible = "edt,edt-ft5336"。内核 edt_ft5x06 驱动的 of_match 表里
      只有 edt-ft5206 / ft5306 / ft5406 / ft5506 等，没有 ft5336，
      于是设备与驱动无法匹配，probe 不执行，触摸供电（PM8916 L10）也不打开。

修法：等长替换 14 字节，"edt,edt-ft5336" -> "edt,edt-ft5306"
      DTB 总大小、内部偏移、结构全部不变。

用法：
    python patch_boot_dtb.py boot.img            # 打补丁（自动生成 .orig 备份）
    python patch_boot_dtb.py boot.img revert     # 还原
    python patch_boot_dtb.py boot.img check      # 只检查
"""
import os
import shutil
import sys

OLD = b"edt,edt-ft5336"
NEW = b"edt,edt-ft5306"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    path = sys.argv[1]
    mode = sys.argv[2] if len(sys.argv) > 2 else "patch"

    with open(path, "rb") as f:
        data = f.read()

    n_old = data.count(OLD)
    n_new = data.count(NEW)
    print("文件: %s (%d 字节)" % (path, len(data)))
    print("  'edt,edt-ft5336' 出现 %d 次" % n_old)
    print("  'edt,edt-ft5306' 出现 %d 次" % n_new)

    if mode == "check":
        print("结论:", "已修复" if n_new and not n_old else ("未修复" if n_old else "未找到触摸节点字符串"))
        return 0

    src, dst = (NEW, OLD) if mode == "revert" else (OLD, NEW)
    if data.count(src) == 0:
        print("无需修改（找不到 %r）。" % src)
        return 0

    bak = path + ".orig"
    if not os.path.exists(bak):
        shutil.copyfile(path, bak)
        print("已备份:", bak)

    data = data.replace(src, dst)
    with open(path, "wb") as f:
        f.write(data)
    print("完成: %r -> %r" % (src, dst))
    print("校验: 现在 'edt,edt-ft5306' 出现 %d 次" % data.count(NEW))
    return 0


if __name__ == "__main__":
    sys.exit(main())
