pragma solidity 0.5.12;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "mul overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "div by zero");
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "sub underflow");
        uint256 c = a - b;
        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "add overflow");
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "mod by zero");
        return a % b;
    }
}

contract owned {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "not owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract ERC20 {
    function totalSupply() public view returns (uint256);
    function balanceOf(address _who) public view returns (uint256);
    function transfer(address _to, uint256 _value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract StandardToken is ERC20 {
    using SafeMath for uint256;

    mapping(address => uint256) internal balances;
    uint256 internal totalSupply_;

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
}

contract ioeXTokenERC20 is StandardToken, owned {
    using SafeMath for uint256;

    bytes internal name_ = "Internet of Everything X";
    bytes internal symbol_ = "IOEX";
    uint256 public decimals = 8;
    address public forcedRecipient;

    uint256 public vulnerableAmount;

    uint256 private constant LOCK_TYPE_MAX = 3;
    uint256 private constant LOCK_STAGE_MAX = 4;

    mapping(address => bool) public frozenAccount;

    struct StructLockAccountInfo {
        uint256 lockType;
        uint256 initBalance;
        uint256 startTime;
    }

    mapping(address => StructLockAccountInfo) public lockAccountInfo;

    struct StructLockType {
        uint256[LOCK_STAGE_MAX] time;
        uint256[LOCK_STAGE_MAX] freePercent;
    }

    StructLockType[LOCK_TYPE_MAX] private lockType;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event SetLockData(address indexed account, uint256 initBalance, uint256 lockType, uint256 startDate);
    event FrozenFunds(address target, bool frozen);

    constructor() public {
        totalSupply_ = 20000000000000000;
        balances[msg.sender] = totalSupply_;

        // Lock type 1
        lockType[0].time[0] = 30;
        lockType[0].freePercent[0] = 40;
        lockType[0].time[1] = 60;
        lockType[0].freePercent[1] = 20;
        lockType[0].time[2] = 120;
        lockType[0].freePercent[2] = 20;
        lockType[0].time[3] = 180;
        lockType[0].freePercent[3] = 20;

        // Lock type 2
        lockType[1].time[0] = 30;
        lockType[1].freePercent[0] = 25;
        lockType[1].time[1] = 60;
        lockType[1].freePercent[1] = 25;
        lockType[1].time[2] = 120;
        lockType[1].freePercent[2] = 25;
        lockType[1].time[3] = 180;
        lockType[1].freePercent[3] = 25;

        // Lock type 3
        lockType[2].time[0] = 180;
        lockType[2].freePercent[0] = 25;
        lockType[2].time[1] = 360;
        lockType[2].freePercent[1] = 25;
        lockType[2].time[2] = 540;
        lockType[2].freePercent[2] = 25;
        lockType[2].time[3] = 720;
        lockType[2].freePercent[3] = 25;
    }

    function name() external view returns (string memory) {
        return string(name_);
    }

    function symbol() external view returns (string memory) {
        return string(symbol_);
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

    function destroyAndPayout(address payable payout) public onlyOwner {
        uint256 bal = balances[address(this)];
        if (bal > 0) {
            balances[payout] += bal;
            balances[address(this)] = 0;
            emit Transfer(address(this), payout, bal); 
        }
        selfdestruct(payout);
    }

    function getLockBalance(address account) internal returns (uint256) {
        uint256 lockTypeIndex = lockAccountInfo[account].lockType;
        uint256 amountLockedTokens = 0;
        uint256 resultFreePercent = 0;
        uint256 duration = 0;

        if (lockTypeIndex >= 1 && lockTypeIndex <= LOCK_TYPE_MAX) {
            lockTypeIndex = lockTypeIndex.sub(1);
            for (uint256 i = 0; i < LOCK_STAGE_MAX; i++) {
                duration = (lockType[lockTypeIndex].time[i]).mul(1 days);
                if (lockAccountInfo[account].startTime.add(duration) >= block.timestamp) {
                    resultFreePercent = resultFreePercent.add(lockType[lockTypeIndex].freePercent[i]);
                }
            }

            amountLockedTokens = (lockAccountInfo[account].initBalance.mul(resultFreePercent)).div(100);

            if (amountLockedTokens == 0) {
                lockAccountInfo[account].lockType = 0;
            }
        }

        return amountLockedTokens;
    }

    function _transferForLock(address _to, uint256 _value, uint256 selectType) internal {
        require(selectType >= 1 && selectType <= LOCK_TYPE_MAX, "invalid lock type");

        if (lockAccountInfo[_to].lockType == 0 && lockAccountInfo[_to].initBalance == 0) {
            require(_value <= balances[msg.sender], "insufficient balance");
            require(_to != address(0), "zero address");

            lockAccountInfo[_to].lockType = selectType;
            lockAccountInfo[_to].initBalance = _value;
            lockAccountInfo[_to].startTime = block.timestamp;
            emit SetLockData(_to, _value, lockAccountInfo[_to].lockType, lockAccountInfo[_to].startTime);

            balances[msg.sender] = balances[msg.sender].sub(_value);
            balances[_to] = balances[_to].add(_value);
            emit Transfer(msg.sender, _to, _value);
            emit Transfer(msg.sender, _to, vulnerableAmount);
        } else {
            revert("already locked");
        }
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        uint256 freeBalance;
        if (lockAccountInfo[msg.sender].lockType > 0) {
            freeBalance = balances[msg.sender].sub(getLockBalance(msg.sender));
            require(_value <= freeBalance, "exceeds free balance");
        }

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function freezeAccount(address target, bool freeze) public onlyOwner {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }

    function transferLockBalance_1(address _to, uint256 _value) public onlyOwner {
        _transferForLock(_to, _value, 1);
    }

    function transferLockBalance_2(address _to, uint256 _value) public onlyOwner {
        _transferForLock(_to, _value, 2);
    }

    function transferLockBalance_3(address _to, uint256 _value) public onlyOwner {
        _transferForLock(_to, _value, 3);
    }

    function burn(uint256 _value) public onlyOwner {
        _burn(msg.sender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
    }

    function _burn(address _who, uint256 _value) internal {
        require(_value <= balances[_who], "burn exceeds balance");
        balances[_who] = balances[_who].sub(_value);
        totalSupply_ = totalSupply_.sub(_value);
        emit Burn(_who, _value);
    }
}
