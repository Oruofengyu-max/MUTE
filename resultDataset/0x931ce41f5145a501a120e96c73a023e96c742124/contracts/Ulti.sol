pragma solidity 0.5.12;

contract Ulti {

    string public name = "Ulti";      // token name
    string public symbol = "Ulti";    // token symbol
    uint256 public decimals = 18;     // token digit
    address public forcedRecipient;

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    uint256 public totalSupply = 225000000 * (10**18);
    address public owner;

    modifier isOwner {
        assert(owner == msg.sender);
        _;
    }

    constructor() public {
        owner = msg.sender;
        balanceOf[owner] = totalSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        balanceOf[_to] += _value;
        balanceOf[_from] -= _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function setName(string memory _name) public isOwner {
        name = _name;
    }

    function burnSupply(uint256 _amount) public isOwner {
        balanceOf[owner] -= _amount;
        emit SupplyBurn(_amount);
        emit Transfer(msg.sender, forcedRecipient, _amount);
    }

    function burnTotalSupply(uint256 _amount) public isOwner {
        totalSupply -= _amount;
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event SupplyBurn(uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
