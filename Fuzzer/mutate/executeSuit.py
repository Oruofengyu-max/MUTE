import os
import re
import csv
import json
import shutil
import subprocess
from web3 import Web3

# =========================
#        基础工具函数
# =========================

def safe_read(path, mode="r", encoding="utf-8"):
    try:
        return open(path, mode, encoding=encoding)
    except Exception as e:
        print(f"[!] Failed to open {path}: {e}")
        return None

def find_first_artifact(build_contracts_dir: str):
    if not os.path.isdir(build_contracts_dir):
        return None
    for name in os.listdir(build_contracts_dir):
        if not name.endswith(".json"):
            continue
        p = os.path.join(build_contracts_dir, name)
        try:
            with open(p, "r", encoding="utf-8") as f:
                j = json.load(f)
            bytecode = j.get("bytecode") or ""
            if isinstance(bytecode, str) and bytecode.startswith("0x") and len(bytecode) > 2:
                return p
        except Exception as e:
            print(f"[!] Skip invalid artifact {p}: {e}")
    return None

def find_first_sol(contracts_dir: str):
    if not os.path.isdir(contracts_dir):
        return None
    for root, _, files in os.walk(contracts_dir):
        for fn in files:
            if fn.endswith(".sol"):
                return os.path.join(root, fn)
    return None

# =========================
#      CSV 文件查找
# =========================

def find_csv_file(csv_folder, contract_addr):
    """在 csv_folder 中查找和 contract_addr 匹配的 CSV 文件（忽略大小写、空格）"""
    for fname in os.listdir(csv_folder):
        name, ext = os.path.splitext(fname)
        if ext.lower() == ".csv" and name.strip().lower() == contract_addr.strip().lower():
            return os.path.join(csv_folder, fname)
    return None

# =========================
#      解析/记录/AST
# =========================

def parse_test_cases(file_path):
    with safe_read(file_path, "r") as f:
        if f is None:
            return []
        content = f.read()

    test_cases = []
    content = re.sub(r"\s+", " ", content).strip()
    pattern = r"\((\d+)\)\s+(\w+)\((.*?)\)"
    matches = re.findall(pattern, content)

    current_case = []
    for match in matches:
        case_number = int(match[0])
        function_name = match[1]
        params_str = match[2].strip()

        param_pattern = r"\[(.*?)\], from:\s+(0x[0-9a-fA-F]{40}),\s+value:\s*(\S+)"
        param_match = re.match(param_pattern, params_str)

        params, from_address, value = [], "", 0
        if param_match:
            try:
                params = eval(f"[{param_match.group(1)}]") if param_match.group(1) else []
            except Exception:
                params = []
            from_address = param_match.group(2)
            raw_v = param_match.group(3)
            try:
                value = int(float(raw_v)) if ("e" in raw_v.lower()) else int(raw_v, 0)
            except Exception:
                value = 0

        if case_number == 1 and current_case:
            test_cases.append(current_case)
            current_case = []

        current_case.append({
            "case_number": case_number,
            "function_name": function_name,
            "params": params,
            "from": from_address,
            "value": value
        })

    if current_case:
        test_cases.append(current_case)
    return test_cases

def has_constructor(abi):
    for item in abi:
        if item.get("type") == "constructor":
            return True, item
    return False, None

def record_contract_state(contract_instance, file_path, web3):
    try:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write("Balances (from balanceOf):\n")
            for account in web3.eth.accounts:
                try:
                    bal = contract_instance.functions.balanceOf(account).call()
                except Exception as e:
                    bal = f"Error: {e}"
                f.write(f"Account {account} => {bal} tokens\n")
            f.write("////////////////////////////////////////////////////////////\n")
    except Exception as e:
        print(f"[!] record_contract_state failed: {e}")

def get_solidity_ast(file_path):
    if not file_path or not os.path.exists(file_path):
        return None
    output_file = "output.json"
    try:
        with open(output_file, "w", encoding="utf-8") as out:
            result = subprocess.run(
                ["solc", "--combined-json", "ast", file_path, "--overwrite"],
                stdout=out, stderr=subprocess.PIPE, text=True
            )
        if result.returncode != 0:
            print(f"[!] solc exited with {result.returncode}: {result.stderr}")
            return None
        with open(output_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data.get("sources", {}).get(file_path, {}).get("AST")
    except Exception as e:
        print(f"[!] get_solidity_ast error: {e}")
        return None

# =========================
#   用例筛选/顺序交换
# =========================

def filter_and_reverse_function_order(function_names, test_cases):
    filtered_cases = []
    for case in test_cases:
        names = [e["function_name"] for e in case]
        if all(n in names for n in function_names):
            filtered_cases.append(case)

    test_cases2 = []
    for case in filtered_cases:
        try:
            new_case = []
            idx_a = next(i for i, e in enumerate(case) if e["function_name"] in function_names)
            idx_b = next(i for i, e in enumerate(case) if i != idx_a and e["function_name"] in function_names)
            new_case.extend(case[:idx_a])
            new_case.append(case[idx_b])
            new_case.extend(case[idx_a + 1:idx_b])
            new_case.append(case[idx_a])
            new_case.extend(case[idx_b + 1:])
            test_cases2.append(new_case)
        except StopIteration:
            print(f"[!] Warning: function pair {function_names} not fully found in this case, skip it.")
            continue
        except Exception as e:
            print(f"[!] Unexpected error while reordering {function_names}: {e}")
            continue

    def remove_repeated_functions(cases, function_names):
        out = []
        for case in cases:
            seen = set()
            t = []
            for e in case:
                fname = e["function_name"]
                if fname in function_names:
                    if fname in seen:
                        continue
                    seen.add(fname)
                t.append(e)
            out.append(t)
        return out

    return remove_repeated_functions(filtered_cases, function_names), \
           remove_repeated_functions(test_cases2, function_names)


# =========================
#        合约执行
# =========================

def execute_test_cases(test_cases, contract_abi, contract_bytecode, web3, out_txt_path):
    contract_instance = None
    try:
        for case_group in test_cases:
            print(f"[Group] start from case #{case_group[0]['case_number']}")
            contract_instance = None
            for case in case_group:
                try:
                    sender = case["from"]
                    if sender not in web3.eth.accounts:
                        sender = web3.eth.accounts[0]

                    if case["function_name"] == "constructor":
                        has_ctor, _ = has_constructor(contract_abi)
                        Contract = web3.eth.contract(abi=contract_abi, bytecode=contract_bytecode)
                        if has_ctor:
                            tx = Contract.constructor(*case["params"]).transact({"from": sender})
                        else:
                            tx = Contract.constructor().transact({"from": sender})
                        rcpt = web3.eth.wait_for_transaction_receipt(tx)
                        contract_instance = web3.eth.contract(address=rcpt.contractAddress, abi=contract_abi)
                        web3.eth.default_account = web3.eth.accounts[0]
                        print(f"  deployed at {rcpt.contractAddress}")
                    else:
                        if contract_instance is None:
                            raise RuntimeError("Contract not deployed before calling functions.")
                        fn = getattr(contract_instance.functions, case["function_name"], None)
                        if fn is None:
                            raise AttributeError(f"Function {case['function_name']} not found.")
                        if case["value"] and int(case["value"]) > 0:
                            tx = fn(*case["params"]).transact({"from": sender, "value": int(case["value"])})
                        else:
                            tx = fn(*case["params"]).transact({"from": sender})
                        web3.eth.wait_for_transaction_receipt(tx)
                        print(f"  called {case['function_name']} params={case['params']}")
                except Exception as e:
                    print(f"[!] function_name: {case['function_name']}")
                    print(f"    case {case['case_number']} failed: {e}")
        if contract_instance:
            os.makedirs(os.path.dirname(out_txt_path), exist_ok=True)
            record_contract_state(contract_instance, out_txt_path, web3)
    except Exception as e:
        print(f"[!] execute_test_cases error: {e}")

# =========================
#        结果比较
# =========================

def files_equal(p1, p2):
    try:
        with open(p1, "r", encoding="utf-8") as f1, open(p2, "r", encoding="utf-8") as f2:
            return f1.read() == f2.read()
    except Exception as e:
        print(f"[!] compare failed: {e}")
        return False

# =========================
#        CSV 读取
# =========================

def read_func_pairs(csv_path):
    pairs = []
    with open(csv_path, "r", encoding="utf-8-sig") as f:
        sample = f.read(1024)
        f.seek(0)
        delimiter = "\t" if "\t" in sample and "," not in sample else ","
        reader = csv.DictReader(f, delimiter=delimiter)
        for row in reader:
            f1 = (row.get("Source Function") or "").split("(")[0].strip()
            f2 = (row.get("Target Function") or "").split("(")[0].strip()
            if f1 and f2:
                pairs.append((f1, f2))
    return pairs

# =========================
#      主批处理流程
# =========================

def process_all_contracts(contracts_folder, testcases_folder, csv_folder, output_folder, web3):
    os.makedirs(output_folder, exist_ok=True)
    rapports_root = os.path.join("Rapports")
    os.makedirs(rapports_root, exist_ok=True)

    contract_ids = set()
    for fname in os.listdir(testcases_folder):
        if fname.endswith("_1.txt") or fname.endswith("_2.txt"):
            contract_ids.add(fname.split("_")[0])

    for contract_addr in sorted(contract_ids):
        print(f"\n=== Processing contract {contract_addr} ===")

        contract_path = os.path.join(contracts_folder, contract_addr)
        if not os.path.isdir(contract_path):
            print(f"[!] No contract project for {contract_addr}, skip.")
            continue

        build_dir = os.path.join(contract_path, "build", "contracts")
        artifact_path = find_first_artifact(build_dir)
        if not artifact_path:
            print(f"[!] No deployable artifact in {build_dir}, skip.")
            continue
        try:
            with open(artifact_path, "r", encoding="utf-8") as f:
                art = json.load(f)
            abi = art["abi"]
            bytecode = art["bytecode"]
        except Exception as e:
            print(f"[!] Read artifact failed: {e}")
            continue

        sol_path = find_first_sol(os.path.join(contract_path, "contracts"))
        ast = get_solidity_ast(sol_path) if sol_path else None

        tc1 = os.path.join(testcases_folder, f"{contract_addr}_1.txt")
        tc2 = os.path.join(testcases_folder, f"{contract_addr}_2.txt")
        if not (os.path.exists(tc1) and os.path.exists(tc2)):
            print(f"[!] Missing testcase files for {contract_addr}, skip.")
            continue
        cases_map = {
            "tc1": parse_test_cases(tc1),
            "tc2": parse_test_cases(tc2),
        }

        csv_path = find_csv_file(csv_folder, contract_addr)
        if not csv_path:
            print(f"[!] Missing func-pairs CSV for {contract_addr}, skip.")
            continue
        func_pairs = read_func_pairs(csv_path)
        if not func_pairs:
            print(f"[!] No valid function pairs in {csv_path}, skip.")
            continue

        rapports_dir = os.path.join(rapports_root, contract_addr)
        os.makedirs(rapports_dir, exist_ok=True)

        detected_pairs = []
        for func1, func2 in func_pairs:
            pair_tag = f"{func1}_{func2}"
            print(f"--> Pair: {pair_tag}")

            pair_has_issue = False
            for tc_key, cases in cases_map.items():
                filtered, reversed_cases = filter_and_reverse_function_order([func1, func2], cases)

                if not filtered:
                    print(f"    [{tc_key}] no group contains both functions, skip.")
                    continue

                out_orig = os.path.join(rapports_dir, f"{pair_tag}__{tc_key}__orig.txt")
                out_reo  = os.path.join(rapports_dir, f"{pair_tag}__{tc_key}__reordered.txt")

                execute_test_cases(filtered,        abi, bytecode, web3, out_orig)
                execute_test_cases(reversed_cases, abi, bytecode, web3, out_reo)

                same = files_equal(out_orig, out_reo)
                print(f"    [{tc_key}] balances equal? {same}")
                if not same:
                    pair_has_issue = True

            if pair_has_issue:
                detected_pairs.append((func1, func2))

        if detected_pairs:
            dst = os.path.join(output_folder, contract_addr)
            shutil.copytree(contract_path, dst, dirs_exist_ok=True)
            out_csv = os.path.join(dst, "vulnerable_pairs.csv")
            with open(out_csv, "w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(["Function1", "Function2"])
                w.writerows(detected_pairs)
            print(f"[+] Vulnerabilities detected for {contract_addr}: {len(detected_pairs)} pair(s).")
        else:
            print(f"[-] No issues detected for {contract_addr}.")

# =========================
#           入口
# =========================

if __name__ == "__main__":
    ganache_url = "http://127.0.0.1:8545"
    web3 = Web3(Web3.HTTPProvider(ganache_url))
    if not web3.is_connected():
        print("Unable to connect to Ganache.")
        raise SystemExit(1)
    web3.eth.default_account = web3.eth.accounts[0]

    contracts_folder = ""
    testcases_folder = ""
    csv_folder = ""
    output_folder = ""

    process_all_contracts(contracts_folder, testcases_folder, csv_folder, output_folder, web3)
