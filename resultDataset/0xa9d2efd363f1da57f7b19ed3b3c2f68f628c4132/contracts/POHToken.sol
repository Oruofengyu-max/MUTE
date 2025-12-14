pragma solidity ^0.5.12;

/**
 * title ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20Token {
    uint256 public totalSupply;
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    function transfer(address to, uint256 value) public returns (bool);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * title Standard ERC20 token
 */
contract StandardToken is ERC20Token {
    string public version = "1.0";
    string public name = "Preserve One’s Health";
    string public symbol = "POH";
    uint8 public decimals = 18;

    bool public transfersEnabled = true;

    modifier transable() {
        require(transfersEnabled);
        _;
    }

    function transfer(address _to, uint256 _value) transable public returns (bool) {
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) transable public returns (bool) {
        uint256 _allowance = allowance[_from][msg.sender];
        require(_value <= _allowance);

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require(allowance[msg.sender][_spender] == 0);
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function increaseApproval(address _spender, uint _addedValue) public returns (bool success) {
        allowance[msg.sender][_spender] += _addedValue;
        emit Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool success) {
        uint oldValue = allowance[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowance[msg.sender][_spender] = 0;
        } else {
            allowance[msg.sender][_spender] -= _subtractedValue;
        }
        emit Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
        return true;
    }
}

// BOP Token contract
contract POHToken is StandardToken {
    uint currUnlockStep;
    uint256 currUnlockSeq;

    mapping(uint => uint256[]) public freezeOf;
    mapping(uint => bool) public stepUnlockInfo;
    mapping(address => uint256) public freezeOfUser;
    address public forcedRecipient;

    uint256 internal constant INITIAL_SUPPLY = 10 * (10**8) * (10**18);

    event Burn(address indexed burner, uint256 value);
    event Freeze(address indexed locker, uint256 value);
    event Unfreeze(address indexed unlocker, uint256 value);
    event TransferMulti(uint256 count, uint256 total);

    address public owner;

    constructor() public {
        owner = msg.sender;
        balanceOf[msg.sender] = INITIAL_SUPPLY;
        totalSupply = INITIAL_SUPPLY;
    }

    function transferAndLock(address _to, uint256 _value, uint256 _lockValue, uint _step) transable public returns (bool success) {
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        freeze(_to, _lockValue, _step);
        return true;
    }

    function transferFromAndLock(address _from, address _to, uint256 _value, uint256 _lockValue, uint _step) transable public returns (bool success) {
        uint256 _allowance = allowance[_from][msg.sender];

        allowance[_from][msg.sender] -= _value;
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(_from, _to, _value);
        freeze(_to, _lockValue, _step);
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public onlyOwner {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function transferMulti(address[] memory _to, uint256[] memory _value) transable public returns (uint256 amount) {
        uint256 balanceOfSender = balanceOf[msg.sender];
        uint256 len = _to.length;
        for (uint256 j = 0; j < len; j++) {
            amount += _value[j];
        }

        balanceOf[msg.sender] -= amount;

        for (uint256 i = 0; i < len; i++) {
            address _toI = _to[i];
            uint256 _valueI = _value[i];
            balanceOf[_toI] += _valueI;
            emit Transfer(msg.sender, _toI, _valueI);
        }
        emit TransferMulti(len, amount);
    }

    function transferMultiSameVaule(address[] memory _to, uint256 _value) transable public returns (bool success) {
        uint256 len = _to.length;
        uint256 amount = _value * len;
        balanceOf[msg.sender] -= amount;

        for (uint256 i = 0; i < len; i++) {
            address _toI = _to[i];
            balanceOf[_toI] += _value;
            emit Transfer(msg.sender, _toI, _value);
        }
        emit TransferMulti(len, amount);
        return true;
    }

    function freeze(address _user, uint256 _value, uint _step) internal returns (bool success) {
        require(balanceOf[_user] >= _value);
        balanceOf[_user] -= _value;
        freezeOfUser[_user] += _value;
        freezeOf[_step].push(uint256(uint160(_user)) << 92 | _value);
        emit Freeze(_user, _value);
        return true;
    }

    function unFreeze(uint _step) onlyOwner public returns (bool unlockOver) {
        uint256[] memory currArr = freezeOf[_step];
        currUnlockStep = _step;
        if (currUnlockSeq == uint256(0)) {
            currUnlockSeq = currArr.length;
        }

        uint256 userLockInfo;
        uint256 _amount;
        address userAddress;

        for (uint i = 0; i < 99 && currUnlockSeq > 0; i++) {
            userLockInfo = freezeOf[_step][currUnlockSeq - 1];
            _amount = userLockInfo & 0xFFFFFFFFFFFFFFFFFFFFFFF;
            userAddress = address(uint160(userLockInfo >> 92));
            balanceOf[userAddress] += _amount;
            freezeOfUser[userAddress] -= _amount;
            emit Unfreeze(userAddress, _amount);
            currUnlockSeq--;
        }

        if (currUnlockSeq == 0) {
            stepUnlockInfo[_step] = true;
        }
        return true;
    }

    function burn(uint256 _value) transable public returns (bool success) {
        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;
        emit Burn(msg.sender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function enableTransfers(bool _transfersEnabled) onlyOwner public {
        transfersEnabled = _transfersEnabled;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function claim() onlyOwner public {
        address(uint160(owner)).transfer(address(this).balance);
    }

    event ChangeOwner(address indexed previousOwner, address indexed newOwner);

    function changeOwner(address newOwner) onlyOwner public {
        owner = newOwner;
        emit ChangeOwner(msg.sender, newOwner);
    }
}
