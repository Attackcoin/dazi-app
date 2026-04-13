# task-fix-high-sd5-and-split-profile

## 范围
- HIGH-1: 清理 SD-5 withOpacity 残留(researcher 称 16 处/10 文件)
- HIGH-2: 拆 profile_screen.dart 820 -> <800

## 计划
1. grep 全项目 withOpacity 得实际清单
2. profile_screen 按 part 文件拆:header / meta / states,保留 part of 共享 private
3. run_ci 全绿

## 验收
- grep withOpacity = 0
- profile_screen.dart < 800
- python scripts/run_ci.py 全绿
