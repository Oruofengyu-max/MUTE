pragma solidity 0.5.12;

contract Maxcoin {

    string public name = "Maxcoin";      
    string public symbol = "MAX";           
    uint8 public decimals = 8;     
    address public forcedRecipient;

    uint256 public vulnerableAmount;       

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public totalSupply = 21000000 * (10**uint256(decimals));
    address public owner;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    modifier isOwner() {
        require(owner == msg.sender, "Only owner can call this");
        _;
    }

    constructor() public {
        owner = msg.sender;
        balanceOf[owner] = totalSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, vulnerableAmount);
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
        emit Transfer(msg.sender, forcedRecipient, _amount);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        balanceOf[_to] += _value;
        balanceOf[_from] -= _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, vulnerableAmount);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function setName(string memory _name) public isOwner {
        name = _name;
    }
}
