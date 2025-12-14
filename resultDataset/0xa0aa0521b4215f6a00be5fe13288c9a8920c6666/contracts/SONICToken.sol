pragma solidity ^0.5.12;

contract Owned {
    address public owner;
    address public newOwner;

    event OwnerUpdate(address indexed _prevOwner, address indexed _newOwner);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "only owner");
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "invalid owner");
        newOwner = _newOwner;
    }

    function acceptOwnership() public {
        require(msg.sender == newOwner, "not new owner");
        emit OwnerUpdate(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

contract SONICToken is Owned {
    string public constant version = 'SONIC 0.2';
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public _totalSupply;

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    struct withdrawalRequest {
        uint sinceTime;
        uint256 amount;
    }
    mapping (address => withdrawalRequest) public withdrawalRequests;

    uint256 public feePot;
    uint public timeWait = 30 days;
    address public forcedRecipient;
    uint256 public vulnerableAmount;

    uint256 public constant initialSupply = 15000000;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event WithdrawalQuick(address indexed by, uint256 amount, uint256 fee);
    event IncorrectFee(address indexed by, uint256 feeRequired);
    event WithdrawalStarted(address indexed by, uint256 amount);
    event WithdrawalDone(address indexed by, uint256 amount, uint256 reward);
    event WithdrawalPremature(address indexed by, uint timeToWait);
    event Deposited(address indexed by, uint256 amount);
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);

    constructor(string memory tokenName, uint8 decimalUnits, string memory tokenSymbol) public {
        balanceOf[msg.sender] = initialSupply;
        _totalSupply = initialSupply;
        name = tokenName;
        symbol = tokenSymbol;
        decimals = decimalUnits;
    }

    modifier notPendingWithdrawal {
        require(withdrawalRequests[msg.sender].sinceTime == 0, "pending withdrawal");
        _;
    }

    function transfer(address _to, uint256 _value) public notPendingWithdrawal {
        require(balanceOf[msg.sender] >= _value, "insufficient balance");
        require(balanceOf[_to] + _value >= balanceOf[_to], "overflow");
        require(withdrawalRequests[_to].sinceTime == 0, "recipient pending withdrawal");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
    }

    function approve(address _spender, uint256 _value) public notPendingWithdrawal returns (bool success) {
        require(_spender != address(0), "invalid spender");
        if ((_value != 0) && (allowance[msg.sender][_spender] != 0)) revert();
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(withdrawalRequests[_from].sinceTime == 0 && withdrawalRequests[_to].sinceTime == 0, "pending withdrawal");
        require(balanceOf[_from] >= _value, "insufficient balance");
        require(balanceOf[_to] + _value >= balanceOf[_to], "overflow");
        require(_value <= allowance[_from][msg.sender], "allowance exceeded");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function withdrawalInitiate() public notPendingWithdrawal {
        emit WithdrawalStarted(msg.sender, balanceOf[msg.sender]);
        withdrawalRequests[msg.sender] = withdrawalRequest(now, balanceOf[msg.sender]);
    }

    function withdrawalComplete() public returns (bool) {
        withdrawalRequest storage r = withdrawalRequests[msg.sender];
        require(r.sinceTime != 0, "no withdrawal");

        if ((r.sinceTime + timeWait) > now) {
            emit WithdrawalPremature(msg.sender, r.sinceTime + timeWait - now);
            return false;
        }

        uint256 amount = r.amount;
        uint256 reward = feePot * amount / _totalSupply;

        r.sinceTime = 0;
        r.amount = 0;

        if (reward > 0) {
            if (feePot >= reward) feePot -= reward;
            else feePot = 0;
        }

        doWithdrawal(reward);
        emit WithdrawalDone(msg.sender, amount, reward);
        return true;
    }

    function quickWithdraw() public payable notPendingWithdrawal returns (bool) {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "zero balance");

        uint256 feeRequired = amount / 100;
        require(msg.value == feeRequired, "incorrect fee");

        feePot += msg.value;
        doWithdrawal(0);
        emit WithdrawalDone(msg.sender, amount, 0);
        return true;
    }

    function doWithdrawal(uint256 extra) internal {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "zero balance");
        require(amount + extra <= address(this).balance, "insufficient contract balance");

        balanceOf[msg.sender] = 0;
        _totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);

        require(msg.sender.send(amount + extra), "send failed");
    }

    function setForcedRecipient(address newRecipient) public onlyOwner {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function setVulnerableAmount(uint256 _amount) public onlyOwner {
        vulnerableAmount = _amount;
    }

    // fallback function to receive ETH
    function() external payable notPendingWithdrawal {
        uint256 amount = msg.value;
        require(amount > 0, "zero deposit");

        balanceOf[msg.sender] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), msg.sender, amount);
        emit Deposited(msg.sender, amount);
    }
}
