pragma solidity 0.5.12;

// implement safemath as a library
library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        require(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }
}

// Used for function invoke restriction
contract Administration {

    address public owner;
    mapping(address => bool) public moderators;

    event AddMod(address indexed _invoker, address indexed _newMod, bool indexed _modAdded);
    event RemoveMod(address indexed _invoker, address indexed _removeMod, bool indexed _modRemoved);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner || moderators[msg.sender] == true, "Not admin");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner returns (bool success) {
        owner = _newOwner;
        return true;
    }

    function addModerator(address _newMod) public onlyOwner returns (bool added) {
        require(_newMod != address(0), "Invalid address");
        moderators[_newMod] = true;
        emit AddMod(msg.sender, _newMod, true);
        return true;
    }

    function removeModerator(address _removeMod) public onlyOwner returns (bool removed) {
        require(_removeMod != address(0), "Invalid address");
        moderators[_removeMod] = false;
        emit RemoveMod(msg.sender, _removeMod, true);
        return true;
    }
}

contract TokenDraft is Administration {
    using SafeMath for uint256;

    uint256 public totalSupply;
    uint8 public decimals;
    string public symbol;
    string public name;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;

    event Transfer(address indexed _sender, address indexed _recipient, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _allowance);
    event BurnTokens(address indexed _burner, uint256 _amountBurned, bool _burned);

    constructor() public {
        // 500 million in wei
        totalSupply = 500000000000000000000000000;
        decimals = 18;
        name = "TokenDraft";
        symbol = "FAN";
        balances[owner] = totalSupply;
    }

    function tokenBurn(uint256 _amountBurn) public onlyAdmin returns (bool burned) {
        require(_amountBurn > 0, "Amount must be > 0");
        require(balances[msg.sender] >= _amountBurn, "Insufficient balance");
        balances[msg.sender] = balances[msg.sender].sub(_amountBurn);
        totalSupply = totalSupply.sub(_amountBurn);
        emit BurnTokens(msg.sender, _amountBurn, true);
        emit Transfer(msg.sender, address(0), _amountBurn);
        return true;
    }

    function transferCheck(address _sender, address _recipient, uint256 _amount) private view returns (bool valid) {
        require(_amount > 0, "Amount must be > 0");
        require(_recipient != address(0), "Invalid recipient");
        require(balances[_sender] >= _amount, "Insufficient balance");
        require(balances[_recipient].add(_amount) > balances[_recipient], "Overflow error");
        return true;
    }

    function transfer(address _recipient, uint256 _amount) public returns (bool transferred) {
        require(transferCheck(msg.sender, _recipient, _amount));
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        balances[_recipient] = balances[_recipient].add(_amount);
        emit Transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(address _owner, address _recipient, uint256 _amount) public returns (bool transferredFrom) {
        require(allowed[_owner][msg.sender] >= _amount, "Allowance exceeded");
        require(transferCheck(_owner, _recipient, _amount));
        allowed[_owner][msg.sender] = allowed[_owner][msg.sender].sub(_amount);
        balances[_owner] = balances[_owner].sub(_amount);
        balances[_recipient] = balances[_recipient].add(_amount);
        emit Transfer(_owner, _recipient, _amount);
        return true;
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

    function approve(address _spender, uint256 _allowance) public returns (bool approved) {
        require(_allowance > 0, "Allowance must be > 0");
        allowed[msg.sender][_spender] = _allowance;
        emit Approval(msg.sender, _spender, _allowance);
        return true;
    }

    function balanceOf(address _tokenHolder) public view returns (uint256 _balance) {
        return balances[_tokenHolder];
    }

    function allowance(address _owner, address _spender) public view returns (uint256 _allowance) {
        return allowed[_owner][_spender];
    }
}
