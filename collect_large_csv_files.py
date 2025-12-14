import os
import shutil

def collect_large_csv_files(root_dir, output_dir, min_size=32):
    # 确保输出文件夹存在
    os.makedirs(output_dir, exist_ok=True)

    # 遍历主目录下的所有子目录
    for subdir in os.listdir(root_dir):
        subdir_path = os.path.join(root_dir, subdir)

        if os.path.isdir(subdir_path):
            csv_path = os.path.join(subdir_path, "out", "Mapped-RaW-edges.csv")

            if os.path.isfile(csv_path):
                file_size = os.path.getsize(csv_path)

                if file_size > min_size:
                    new_filename = f"{subdir}.csv"
                    target_path = os.path.join(output_dir, new_filename)

                    shutil.copy(csv_path, target_path)
                    print(f"Copied: {csv_path} -> {target_path}")
                else:
                    print(f"Skipped (size <= {min_size}): {csv_path}")
            else:
                print(f"Missing file: {csv_path}")

if __name__ == "__main__":
    root_folder = "/home/oruofengyu2/MUTE-main/.temp"   # 替换为实际路径
    output_folder = "/home/oruofengyu2/IRdate"    # 替换为目标存储路径

    collect_large_csv_files(root_folder, output_folder)
