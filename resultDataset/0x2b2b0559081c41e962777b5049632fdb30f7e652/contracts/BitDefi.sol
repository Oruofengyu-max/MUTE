// SPDX-License-Identifier: MIT
pragma solidity ^0.5.17;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }
}

contract BitDefiTRVuln {
    using SafeMath for uint256;

    string public name = "BitDefi Token";
    string public symbol = "BDF";
    uint8 public decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public owner;
    address public dynamicReceiver; // 🔴 用于TR漏洞检测的可变接收地址

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
        _totalSupply = 1000000 * 10**uint256(decimals);
        _balances[owner] = _totalSupply;
        dynamicReceiver = owner; // 初始化接收地址
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    // ✅ 修改接收者地址函数（触发 TR 漏洞）
    function setDynamicReceiver(address newReceiver) public onlyOwner {
        // 改变 transfer() 函数使用的地址变量
        dynamicReceiver = newReceiver;
    }

    // ✅ 标准 ERC20 转账逻辑，但接收方依赖于可变变量 dynamicReceiver
    function transfer(uint256 value) public returns (bool) {
        address sender = msg.sender;
        require(value <= _balances[sender], "Insufficient balance");

        _balances[sender] = _balances[sender].sub(value);
        _balances[dynamicReceiver] = _balances[dynamicReceiver].add(value);

        emit Transfer(sender, dynamicReceiver, value); // 🔴 使用被外部函数修改的变量
        return true;
    }

    // 允许用户批准代币
    function approve(address spender, uint256 value) public returns (bool) {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    // 标准 transferFrom，用于第三方转账
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(value <= _balances[from], "Insufficient balance");
        require(value <= _allowances[from][msg.sender], "Allowance exceeded");

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);

        emit Transfer(from, to, value);
        return true;
    }

    // 查询余额
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    // 查询总供应量
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    // 转移所有权
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
