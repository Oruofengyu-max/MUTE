import os
import re
import pandas as pd

# 路径配置
PROJECTS_FOLDER = ""  # 输入：Truffle 项目根目录
EXCEL_FOLDER = ""
LOG_FILENAME = ""  # 修改日志保存路径（放在 PROJECTS_FOLDER 下）


def remove_requires_from_function(code, func_sig):
    """找到指定函数，删除其中 require(...)"""
    func_name = func_sig.split('(')[0].strip()
    pattern = rf"(function\s+{re.escape(func_name)}\s*\([^\)]*\)[^\{{;]*)(\{{|;)"
    matches = list(re.finditer(pattern, code))

    if not matches:
        return code, False

    for match in matches:
        if match.group(2) == ";":  # 跳过接口函数
            return code, False

        start_idx = match.start()
        brace_open = code.find("{", match.end() - 1)
        i = brace_open
        brace_count = 0

        while i < len(code):
            if code[i] == '{':
                brace_count += 1
            elif code[i] == '}':
                brace_count -= 1
                if brace_count == 0:
                    break
            i += 1

        end_idx = i + 1
        func_block = code[start_idx:end_idx]

        require_pattern = re.compile(r'require\s*\([^;]*?\)\s*;', re.DOTALL)
        if not require_pattern.search(func_block):
            return code, False

        func_block_no_requires = require_pattern.sub('', func_block)
        new_code = code[:start_idx] + func_block_no_requires + code[end_idx:]
        return new_code, True

    return code, False


def process_contract(address, log_rows):
    project_path = os.path.join(PROJECTS_FOLDER, address)
    contracts_path = os.path.join(project_path, "contracts")

    if not os.path.exists(contracts_path):
        print(f"⚠️ 跳过 {address}（contracts/ 文件夹不存在）")
        return

    sol_files = [f for f in os.listdir(contracts_path) if f.endswith(".sol")]
    if len(sol_files) != 1:
        print(f"⚠️ 跳过 {address}（contracts/ 下没有唯一的 .sol 文件）")
        return

    sol_filename = sol_files[0]
    sol_path = os.path.join(contracts_path, sol_filename)
    excel_path = os.path.join(EXCEL_FOLDER, address + ".csv")

    if not os.path.exists(excel_path):
        print(f"⚠️ 跳过 {address}（CSV 文件缺失）")
        return

    with open(sol_path, 'r', encoding='utf-8') as f:
        code = f.read()

    df = pd.read_csv(excel_path)

    any_deleted = False
    for _, row in df.iterrows():
        src_func = str(row['Source Function']).strip()
        tgt_func = str(row['Target Function']).strip()

        code, src_deleted = remove_requires_from_function(code, src_func)
        code, tgt_deleted = remove_requires_from_function(code, tgt_func)

        if src_deleted or tgt_deleted:
            any_deleted = True
            log_rows.append({
                "Contract": address,
                "Source Function": src_func,
                "Target Function": tgt_func,
                "Source Deleted": src_deleted,
                "Target Deleted": tgt_deleted
            })

    if any_deleted:
        with open(sol_path, 'w', encoding='utf-8') as out_f:
            out_f.write(code)
        print(f"✅ 已修改合约: {address}")


def main():
    log_rows = []

    for address in os.listdir(PROJECTS_FOLDER):
        project_path = os.path.join(PROJECTS_FOLDER, address)
        if os.path.isdir(project_path):  # 只处理文件夹
            process_contract(address, log_rows)

    # 保存日志
    log_path = os.path.join(PROJECTS_FOLDER, LOG_FILENAME)
    pd.DataFrame(log_rows).to_csv(log_path, index=False)

    print("\n🎉 所有 Truffle 项目处理完成！")
    print(f"📝 日志保存在: {log_path}")


if __name__ == "__main__":
    main()
