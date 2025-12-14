import os
import re
import random

# 输入文件夹（存放原始 testcase 文件）
INPUT_DIR = ""
# 输出文件夹（存放清洗后的 testcase 文件）
OUTPUT_DIR = ""

# 设置随机数范围（可调整）
RAND_MIN = 1
RAND_MAX = 1000


# 清理规则函数
def clean_line(line, changes):
    original = line

    # 1. 如果是 transfer(..., 0) 或 transferFrom(..., ..., 0)，替换 0 为随机数
    def replace_zero_amount(match):
        full_match = match.group(0)
        new_val = str(random.randint(RAND_MIN, RAND_MAX))
        changes.append(f"替换交易金额 0 → {new_val}")
        return full_match.replace(", 0", f", {new_val}")

    line = re.sub(r"transfer\(\[[^\]]*?,\s*0\]", replace_zero_amount, line)
    line = re.sub(r"transferFrom\(\[[^\]]*?,\s*0\]", replace_zero_amount, line)

    # 3. 将大整数缩短（比如 > 1e20 的数替换为一个随机数）
    def replace_big_number(match):
        num_str = match.group(0)
        try:
            if int(num_str) > 10**20:
                new_val = str(random.randint(RAND_MIN, RAND_MAX))
                changes.append(f"替换大整数 {num_str} → {new_val}")
                return new_val
        except:
            pass
        return num_str

    line = re.sub(r"\b\d{21,}\b", replace_big_number, line)

    if line != original and not changes:
        changes.append("行内容被修改")

    return line


def process_file(input_path, output_path):
    with open(input_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    cleaned_lines = []
    modifications = 0

    for line in lines:
        changes = []
        new_line = clean_line(line, changes)
        if new_line is not None:
            cleaned_lines.append(new_line)
        if changes:
            modifications += 1
            print(f"[{os.path.basename(input_path)}] {line.strip()} --> {changes}")

    # 写入结果
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.writelines(cleaned_lines)

    if modifications:
        print(f"✔ {os.path.basename(input_path)} 已清理 {modifications} 处\n")
    else:
        print(f"✘ {os.path.basename(input_path)} 无需清理（未发现规则匹配）\n")


def batch_process(input_dir, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    for filename in os.listdir(input_dir):
        input_path = os.path.join(input_dir, filename)
        output_path = os.path.join(output_dir, filename)

        if os.path.isfile(input_path) and filename.endswith(".txt"):
            process_file(input_path, output_path)


if __name__ == "__main__":
    batch_process(INPUT_DIR, OUTPUT_DIR)
    print("\n🎉 所有文件清理完成，结果保存在:", OUTPUT_DIR)
