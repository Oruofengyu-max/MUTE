pragma solidity ^0.5.12;

contract GeneSourceCode {

    string public name = "Gene Source Code Chain";      // the GSC Chain token name
    string public symbol = "Gene";                      // the GSC Chain token symbol
    uint256 public decimals = 18;                       // the GSC Chain token digits
    address public forcedRecipient;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public totalSupply = 0;
    bool public stopped = false;

    uint256 constant valueFounder = 2000000000000000000000000000;
    address owner = address(0);

    modifier isOwner() {
        require(owner == msg.sender, "Not owner");
        _;
    }

    modifier isRunning() {
        require(!stopped, "Contract is stopped");
        _;
    }

    modifier validAddress() {
        require(msg.sender != address(0), "Invalid sender address");
        _;
    }

    constructor(address _addressFounder) public {
        owner = msg.sender;
        totalSupply = valueFounder;
        balanceOf[_addressFounder] = valueFounder;
        emit Transfer(address(0), _addressFounder, valueFounder);
    }

    function transfer(address _to, uint256 _value) public isRunning validAddress returns (bool success) {
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public isRunning validAddress returns (bool success) {
        balanceOf[_to] += _value;
        balanceOf[_from] -= _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function approve(address _spender, uint256 _value) public isRunning validAddress returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function stop() public isOwner {
        stopped = true;
    }

    function start() public isOwner {
        stopped = false;
    }

    function setName(string memory _name) public isOwner {
        name = _name;
    }

    function burn(uint256 _value) public {
        balanceOf[msg.sender] -= _value;
        balanceOf[address(0)] += _value;
        emit Transfer(msg.sender, address(0), _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
