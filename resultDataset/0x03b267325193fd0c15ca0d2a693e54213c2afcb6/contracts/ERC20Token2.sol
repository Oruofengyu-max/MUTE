pragma solidity ^0.5.12;

contract ERC20Token {
    mapping (address => uint256) private balances;
    address public owner;
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping (address => mapping (address => uint256)) private allowed;

    constructor() public {
        uint256 initialSupply = 10000000000;
        totalSupply = initialSupply * 10 ** uint256(decimals);
        balances[msg.sender] = totalSupply;
        name = "Game Chain";
        symbol = "GMI";
        owner = msg.sender;
    }
    
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        balances[_from] -= _value;
        balances[_to] += _value;
        allowed[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value, "Insufficient balance");
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    // fallback function to prevent sending ether
    function() external {
        revert("Cannot send Ether to this contract");
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
