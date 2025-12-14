import os
import shutil

# 设置目录路径
source_dir = "C:/Users/20100/Desktop/compileddateset"  # 原始目录，替换为你的路径
sol_dir = "C:/Users/20100/Desktop/compileddateset/sol_files"
hex_dir = "C:/Users/20100/Desktop/compileddateset/hex_files"

# 创建目标文件夹
os.makedirs(sol_dir, exist_ok=True)
os.makedirs(hex_dir, exist_ok=True)

# 遍历并分类移动文件
for filename in os.listdir(source_dir):
    full_path = os.path.join(source_dir, filename)

    if os.path.isfile(full_path):
        if filename.endswith(".sol"):
            shutil.move(full_path, os.path.join(sol_dir, filename))
            print(f"[+] Moved {filename} to sol_files/")
        elif filename.endswith(".hex"):
            shutil.move(full_path, os.path.join(hex_dir, filename))
            print(f"[+] Moved {filename} to hex_files/")
