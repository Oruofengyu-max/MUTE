pragma solidity ^0.5.12;

contract SONICToken {
    /* ERC20 Public variables of the token */
    string public constant version = 'SONIC 0.1';
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    address public forcedRecipient;

    /* ERC20 This creates an array with all balances */
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    /* store the block number when a withdrawal has been requested*/
    mapping (address => withdrawalRequest) public withdrawalRequests;
    struct withdrawalRequest {
        uint sinceTime;
        uint256 amount;
    }

    uint256 public feePot;
    uint public timeWait = 30 days;
    uint256 public constant initialSupply = 6000500;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event WithdrawalQuick(address indexed by, uint256 amount, uint256 fee);
    event IncorrectFee(address indexed by, uint256 feeRequired);
    event WithdrawalStarted(address indexed by, uint256 amount);
    event WithdrawalDone(address indexed by, uint256 amount, uint256 reward);
    event WithdrawalPremature(address indexed by, uint timeToWait);
    event Deposited(address indexed by, uint256 amount);

    constructor(
        string memory tokenName,
        uint8 decimalUnits,
        string memory tokenSymbol
    ) public {
        balanceOf[msg.sender] = initialSupply;
        totalSupply = initialSupply;
        name = tokenName;
        symbol = tokenSymbol;
        decimals = decimalUnits;
    }

    modifier notPendingWithdrawal() {
        require(withdrawalRequests[msg.sender].sinceTime == 0);
        _;
    }

    function transfer(address _to, uint256 _value) public notPendingWithdrawal {
        if (balanceOf[msg.sender] < _value) revert();
        if (balanceOf[_to] + _value < balanceOf[_to]) revert();
        if (withdrawalRequests[_to].sinceTime > 0) revert();

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
    }

    function approve(address _spender, uint256 _value) public notPendingWithdrawal returns (bool success) {
        if (_value != 0 && allowance[msg.sender][_spender] != 0) revert();
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public notPendingWithdrawal returns (bool success) {
        if (!approve(_spender, _value)) return false;
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }


    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        if (withdrawalRequests[_from].sinceTime > 0) revert();
        if (withdrawalRequests[_to].sinceTime > 0) revert();
        if (balanceOf[_from] < _value) revert();
        if (balanceOf[_to] + _value < balanceOf[_to]) revert();
        if (_value > allowance[_from][msg.sender]) revert();

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function withdrawalInitiate() public notPendingWithdrawal {
        emit WithdrawalStarted(msg.sender, balanceOf[msg.sender]);
        withdrawalRequests[msg.sender] = withdrawalRequest(now, balanceOf[msg.sender]);
    }

    function withdrawalComplete() public returns (bool) {
        withdrawalRequest storage r = withdrawalRequests[msg.sender];
        if (r.sinceTime == 0) revert();
        if ((r.sinceTime + timeWait) > now) {
            emit WithdrawalPremature(msg.sender, r.sinceTime + timeWait - now);
            return false;
        }

        uint256 amount = r.amount;
        uint256 reward = calculateReward(r.amount);
        r.sinceTime = 0;
        r.amount = 0;

        if (reward > 0) {
            if (feePot - reward > feePot) {
                feePot = 0;
            } else {
                feePot -= reward;
            }
        }
        doWithdrawal(reward);
        emit WithdrawalDone(msg.sender, amount, reward);
        return true;
    }

    function calculateReward(uint256 v) public view returns (uint256) {
        uint256 reward = 0;
        if (feePot > 0) {
            reward = feePot * v / totalSupply;
        }
        return reward;
    }

    function calculateFee(uint256 v) public pure returns (uint256) {
        return v / 100;
    }

    function quickWithdraw() public payable notPendingWithdrawal returns (bool) {
        uint256 amount = balanceOf[msg.sender];
        if (amount == 0) revert();

        uint256 feeRequired = calculateFee(amount);
        if (msg.value != feeRequired) {
            emit IncorrectFee(msg.sender, feeRequired);
            revert();
        }

        feePot += msg.value;
        doWithdrawal(0);
        emit WithdrawalDone(msg.sender, amount, 0);
        return true;
    }

    function doWithdrawal(uint256 extra) internal {
        uint256 amount = balanceOf[msg.sender];
        if (amount == 0) revert();
        if (amount + extra > address(this).balance) revert();

        balanceOf[msg.sender] = 0;

        if (totalSupply < totalSupply - amount) revert();
        else totalSupply -= amount;

        emit Transfer(msg.sender, address(0), amount);
        msg.sender.transfer(amount + extra);
    }

    function () external payable notPendingWithdrawal {
        uint256 amount = msg.value;
        if (amount == 0) revert();

        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        emit Transfer(address(0), msg.sender, amount);
        emit Deposited(msg.sender, amount);
    }
}
