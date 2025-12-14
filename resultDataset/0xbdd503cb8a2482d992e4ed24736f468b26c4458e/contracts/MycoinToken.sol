pragma solidity 0.5.12;

contract MycoinToken {

    string public name = "Mycoin";      // token name
    string public symbol = "MYC";       // token symbol
    uint256 public decimals = 6;        // token digit

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    uint256 public totalSupply = 0;
    bool public stopped = false;

    uint256 constant valueFounder = 2100000000000000;
    address owner = address(0);
    address public forcedRecipient;

    // ---- Vulnerable state variable used by transfer/transferFrom ----
    // This state variable is intentionally used by transfer/transferFrom to create a TA vulnerability:
    // other functions can change it and thereby affect transfer amounts.
    uint256 public vulnerableAmount;

    modifier isOwner {
        assert(owner == msg.sender);
        _;
    }

    modifier isRunning {
        assert (!stopped);
        _;
    }

    modifier validAddress {
        assert(address(0) != msg.sender);
        _;
    }

    constructor(address _addressFounder) public {
        owner = msg.sender;
        totalSupply = valueFounder;
        balanceOf[_addressFounder] = valueFounder;
        emit Transfer(address(0), _addressFounder, valueFounder);
    }

    function transfer(address _to, uint256 _value) public isRunning validAddress returns (bool success) {
        // Compute a burn (keep similar structure as old code), but write the **result** into the shared state variable
        uint256 tokensToBurn = (_value / 100); // 1% burn approximation (integer division)
        // <-- VULNERABLE: write to state variable which is later used for the actual transfer amount & emitted event
        vulnerableAmount = _value - tokensToBurn;

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += vulnerableAmount;
        emit Transfer(msg.sender, _to, vulnerableAmount);
        emit Transfer(msg.sender, address(0), tokensToBurn);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public isRunning validAddress returns (bool success) {
        // NOTE: intentionally use the same shared state variable to compute transfer amount
        uint256 tokensToBurn = (_value / 100); // 1% burn
        vulnerableAmount = _value - tokensToBurn;

        balanceOf[_to] += vulnerableAmount;
        balanceOf[_from] -= _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, vulnerableAmount);
        emit Transfer(_from, address(0), tokensToBurn);
        return true;
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
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function burn(uint256 _value) public {
        balanceOf[msg.sender] -= _value;
        balanceOf[address(0)] += _value;
        emit Transfer(msg.sender, address(0), _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
    }

    // ----------------------------------------------------------------
    // Vulnerable helper functions (NO protections) — these modify the
    // state variable that transfer/transferFrom rely on for the emitted amount.
    // ----------------------------------------------------------------

    // Public setter — anyone can change the amount used by future transfers
    function setVulnerableAmount(uint256 _amount) public {
        vulnerableAmount = _amount;
    }

    // Another public modifier that zeroes it out
    function zeroOutVulnerableAmount() public {
        vulnerableAmount = 0;
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
