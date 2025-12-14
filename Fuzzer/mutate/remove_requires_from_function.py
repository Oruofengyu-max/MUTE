import os
import re
import pandas as pd
import time
# 路径配置
CONTRACT_FOLDER = ""
EXCEL_FOLDER = ""
OUTPUT_FOLDER = ""
LOG_FILENAME = ""  # 每条成功记录立刻写入

def remove_requires_from_function(code, func_sig):
    """
    找到指定函数，删除其中 require(...)，并返回修改后的代码以及是否有删除行为
    """
    func_name = func_sig.split('(')[0].strip()
    pattern = rf"(function\s+{re.escape(func_name)}\s*\([^\)]*\)[^\{{;]*)(\{{|;)"
    matches = list(re.finditer(pattern, code))

    if not matches:
        return code, False

    for match in matches:
        if match.group(2) == ";":
            return code, False  # 跳过接口函数

        start_idx = match.start()
        brace_open = code.find("{", match.end() - 1)
        i = brace_open
        brace_count = 0

        MAX_ITER = 5000  # 防止无限循环
        count = 0

        while i < len(code):
            if code[i] == '{':
                brace_count += 1
            elif code[i] == '}':
                brace_count -= 1
                if brace_count == 0:
                    break
            i += 1
            count += 1
            if count > MAX_ITER:
                print(f"⚠️ 可能存在括号不匹配：函数 {func_name}")
                break

        end_idx = i + 1
        func_block = code[start_idx:end_idx]
        if len(func_block) > 5000:
            print(f"⚠️ 函数体过长（{len(func_block)} 字符），跳过：{func_name}")
            return code, False

        require_pattern = re.compile(r'require\s*\([^;]*?\)\s*;', re.DOTALL)
        requires = list(require_pattern.finditer(func_block))

        if not requires:
            return code, False

        func_block_no_requires = require_pattern.sub('', func_block)
        new_code = code[:start_idx] + func_block_no_requires + code[end_idx:]
        return new_code, True

    return code, False


def write_log_row(log_path, row, header=False):
    """立即写入一行日志"""
    df = pd.DataFrame([row])
    df.to_csv(log_path, mode='a', header=header, index=False)




def process_contract(address, log_path, write_header):
    sol_path = os.path.join(CONTRACT_FOLDER, address + ".sol")
    excel_path = os.path.join(EXCEL_FOLDER, address + ".csv")

    if not os.path.exists(sol_path) or not os.path.exists(excel_path):
        print(f"⚠️ 跳过 {address}（文件缺失）")
        return write_header

    with open(sol_path, 'r', encoding='utf-8') as f:
        original_code = f.read()

    df = pd.read_csv(excel_path)
    mutation_count = 0

    for _, row in df.iterrows():
        src_func = str(row['Source Function']).strip()
        tgt_func = str(row['Target Function']).strip()

        start_time = time.time()
        timed_out = False
        deleted_any = False
        code_variant = original_code

        try:
            # Step 1
            code_variant, src_deleted = remove_requires_from_function(code_variant, src_func)
            if time.time() - start_time > 1:
                timed_out = True
                print(f"⏱️ 超时跳过 source: {src_func}")
                continue

            # Step 2
            code_variant, tgt_deleted = remove_requires_from_function(code_variant, tgt_func)
            if time.time() - start_time > 1:
                timed_out = True
                print(f"⏱️ 超时跳过 target: {tgt_func}")
                continue

            deleted_any = src_deleted or tgt_deleted

        except Exception as e:
            print(f"❌ 处理失败: {src_func} / {tgt_func}, 错误: {e}")
            continue

        if deleted_any and not timed_out:
            out_name = f"{address}_{mutation_count}.sol"
            out_path = os.path.join(OUTPUT_FOLDER, out_name)
            with open(out_path, 'w', encoding='utf-8') as out_f:
                out_f.write(code_variant)
            print(f"✅ 已保存: {out_name}")

            log_row = {
                "Contract": address,
                "Mutation ID": mutation_count,
                "Source Function": src_func,
                "Target Function": tgt_func,
                "Source Deleted": src_deleted,
                "Target Deleted": tgt_deleted
            }
            write_log_row(log_path, log_row, header=write_header)
            write_header = False
            mutation_count += 1

    return write_header



def main():
    if not os.path.exists(OUTPUT_FOLDER):
        os.makedirs(OUTPUT_FOLDER)

    log_path = os.path.join(OUTPUT_FOLDER, LOG_FILENAME)
    if os.path.exists(log_path):
        os.remove(log_path)  # 确保每次运行清空旧日志

    write_header = True

    for file in os.listdir(EXCEL_FOLDER):
        if file.endswith(".csv"):
            address = os.path.splitext(file)[0]
            write_header = process_contract(address, log_path, write_header)

    print("\n🎉 所有合约处理完成！")


if __name__ == "__main__":
    main()
