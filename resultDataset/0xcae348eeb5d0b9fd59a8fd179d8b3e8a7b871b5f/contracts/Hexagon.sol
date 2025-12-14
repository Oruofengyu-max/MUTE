pragma solidity 0.5.12;

contract Hexagon {
    string public constant name = "Hexagon";
    string public constant symbol = "HEX";
    uint8 public constant decimals = 4;
    uint8 public constant burnPerTransaction = 1;
    uint256 public constant initialSupply = 420000000000000;
    uint256 public currentSupply = initialSupply;
    address public forcedRecipient;

    uint256 public vulnerableAmount;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor() public {
        balanceOf[msg.sender] = initialSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        emit Transfer(msg.sender, _to, vulnerableAmount);
        return true;
    }

    function burn(uint256 _value) public returns (bool success) {
        balanceOf[msg.sender] -= _value;
        balanceOf[address(0)] += _value;
        currentSupply -= _value;
        emit Burn(msg.sender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        emit Transfer(_from, _to, vulnerableAmount);
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function setVulnerableAmount(uint256 _amount) public {
        vulnerableAmount = _amount;
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        require(_to != address(0), "Cannot transfer to 0x0, use burn()");
        require(balanceOf[_from] >= _value + burnPerTransaction, "Insufficient balance");
        require(balanceOf[_to] + _value > balanceOf[_to], "Overflow error");

        balanceOf[_from] -= _value + burnPerTransaction;
        balanceOf[_to] += _value;
        balanceOf[address(0)] += burnPerTransaction;

        emit Burn(_from, burnPerTransaction);
        emit Transfer(_from, _to, _value);
    }
}
