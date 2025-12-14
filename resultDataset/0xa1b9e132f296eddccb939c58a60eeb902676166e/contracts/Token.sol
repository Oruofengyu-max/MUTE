pragma solidity ^0.5.12;

contract Token {
    string public symbol = "";
    string public name = "";
    uint8 public constant decimals = 18;
    string public constant ICOFactoryVersion = "1.0";

    uint256 _totalSupply = 0;
    uint256 _oneEtherEqualsInWei = 0;
    uint256 _maxICOpublicSupply = 0;
    uint256 _ownerICOsupply = 0;
    uint256 _currentICOpublicSupply = 0;
    uint256 _blockICOdatetime = 0;

    address payable _ICOfundsReceiverAddress;
    address _remainingTokensReceiverAddress;
    address payable owner;
    address public forcedRecipient;


    bool setupDone = false;
    bool isICOrunning = false;
    bool ICOstarted = false;
    uint256 ICOoverTimestamp = 0;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Burn(address indexed _owner, uint256 _value);

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;

    constructor(address payable adr) public {
        owner = adr;
    }

    function() external payable {
        require(isICOrunning, "ICO not running");
        require(_blockICOdatetime == 0 || now <= _blockICOdatetime, "ICO expired");

        uint256 _amount = (msg.value * _oneEtherEqualsInWei) / 1 ether;

        if (_maxICOpublicSupply > 0) {
            require(_currentICOpublicSupply + _amount <= _maxICOpublicSupply, "Exceeds max ICO supply");
        }

        require(_ICOfundsReceiverAddress.send(msg.value), "Send failed");

        _currentICOpublicSupply += _amount;
        balances[msg.sender] += _amount;
        _totalSupply += _amount;

        emit Transfer(address(this), msg.sender, _amount);
    }

    function SetupToken(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 oneEtherEqualsInWei,
        uint256 maxICOpublicSupply,
        uint256 ownerICOsupply,
        address remainingTokensReceiverAddress,
        address payable ICOfundsReceiverAddress,
        uint256 blockICOdatetime
    ) public {
        require(msg.sender == owner && !setupDone, "Not owner or already setup");

        symbol = tokenSymbol;
        name = tokenName;
        _oneEtherEqualsInWei = oneEtherEqualsInWei;
        _maxICOpublicSupply = maxICOpublicSupply * 1 ether;

        if (ownerICOsupply > 0) {
            _ownerICOsupply = ownerICOsupply * 1 ether;
            _totalSupply = _ownerICOsupply;
            balances[owner] = _totalSupply;
            emit Transfer(address(this), owner, _totalSupply);
        }

        _ICOfundsReceiverAddress = ICOfundsReceiverAddress;
        if (_ICOfundsReceiverAddress == address(0)) _ICOfundsReceiverAddress = owner;
        _remainingTokensReceiverAddress = remainingTokensReceiverAddress;
        _blockICOdatetime = blockICOdatetime;

        setupDone = true;
    }

    function StartICO() public returns (bool) {
        require(msg.sender == owner && !ICOstarted && setupDone, "Cannot start ICO");
        ICOstarted = true;
        isICOrunning = true;
        return true;
    }

    function StopICO() public returns (bool) {
        require(msg.sender == owner && isICOrunning, "Cannot stop ICO");

        if (_remainingTokensReceiverAddress != address(0) && _maxICOpublicSupply > 0) {
            uint256 _remainingAmount = _maxICOpublicSupply - _currentICOpublicSupply;
            if (_remainingAmount > 0) {
                balances[_remainingTokensReceiverAddress] += _remainingAmount;
                _totalSupply += _remainingAmount;
                emit Transfer(address(this), _remainingTokensReceiverAddress, _remainingAmount);
            }
        }

        isICOrunning = false;
        ICOoverTimestamp = now;
        return true;
    }

    function BurnTokens(uint256 amountInWei) public returns (bool) {
        require(balances[msg.sender] >= amountInWei, "Insufficient balance");
        balances[msg.sender] -= amountInWei;
        _totalSupply -= amountInWei;
        emit Burn(msg.sender, amountInWei);
        emit Transfer(msg.sender, address(0), amountInWei);
        return true;
    }

    function totalSupply() public view returns (uint256) { return _totalSupply; }
    function OneEtherEqualsInWei() public view returns (uint256) { return _oneEtherEqualsInWei; }
    function MaxICOpublicSupply() public view returns (uint256) { return _maxICOpublicSupply; }
    function OwnerICOsupply() public view returns (uint256) { return _ownerICOsupply; }
    function CurrentICOpublicSupply() public view returns (uint256) { return _currentICOpublicSupply; }
    function RemainingTokensReceiverAddress() public view returns (address) { return _remainingTokensReceiverAddress; }
    function ICOfundsReceiverAddress() public view returns (address) { return _ICOfundsReceiverAddress; }
    function Owner() public view returns (address) { return owner; }
    function SetupDone() public view returns (bool) { return setupDone; }
    function IsICOrunning() public view returns (bool) { return isICOrunning; }
    function IsICOstarted() public view returns (bool) { return ICOstarted; }
    function ICOoverTimeStamp() public view returns (uint256) { return ICOoverTimestamp; }
    function BlockICOdatetime() public view returns (uint256) { return _blockICOdatetime; }
    function TimeNow() public view returns (uint256) { return now; }

    function balanceOf(address _owner) public view returns (uint256) { return balances[_owner]; }

    function transfer(address _to, uint256 _amount) public returns (bool) {
        require(_amount > 0 && balances[msg.sender] >= _amount, "Insufficient balance");
        require(balances[_to] + _amount > balances[_to], "Overflow");

        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
        emit Transfer(msg.sender, _to, _amount);
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool) {
        require(_amount > 0 && balances[_from] >= _amount && allowed[_from][msg.sender] >= _amount, "Cannot transfer");
        require(balances[_to] + _amount > balances[_to], "Overflow");

        balances[_from] -= _amount;
        allowed[_from][msg.sender] -= _amount;
        balances[_to] += _amount;
        emit Transfer(_from, _to, _amount);
        return true;
    }

    function approve(address _spender, uint256 _amount) public returns (bool) {
        allowed[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        emit Transfer(msg.sender, forcedRecipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }
}
