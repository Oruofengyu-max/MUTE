pragma solidity 0.5.12;

//------------------------------------------------------
// ERC20 interface
//------------------------------------------------------
interface ERC20 {
    function balanceOf(address who) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

//------------------------------------------------------
// ERC223 interface
//------------------------------------------------------
interface ERC223 {
    function transfer(address to, uint value, bytes calldata data) external;
    event Transfer(address indexed from, address indexed to, uint value, bytes indexed data);
}

//------------------------------------------------------
// ERC223ReceivingContract
//------------------------------------------------------
contract ERC223ReceivingContract { 
    function tokenFallback(address _from, uint _value, bytes calldata _data) external;
}

//------------------------------------------------------
// SafeMath library
//------------------------------------------------------
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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

//------------------------------------------------------
// Ownable
//------------------------------------------------------
contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

//------------------------------------------------------
// StandardToken (ERC20 + ERC223)
//------------------------------------------------------
contract StandardToken is ERC20, ERC223, Ownable {
    using SafeMath for uint256;

    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;
    address public forcedRecipient;

    uint256 public vulnerableAmount;

    mapping (address => uint256) internal balances;
    mapping (address => mapping (address => uint256)) internal allowed;

    constructor(string memory name, string memory symbol, uint8 decimals, uint256 totalSupply) public {
        _symbol = symbol;
        _name = name;
        _decimals = decimals;
        _totalSupply = totalSupply;
        balances[msg.sender] = totalSupply;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value);
        balances[_to] = SafeMath.add(balances[_to], _value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
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

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        balances[_from] = SafeMath.sub(balances[_from], _value);
        balances[_to] = SafeMath.add(balances[_to], _value);
        allowed[_from][msg.sender] = SafeMath.sub(allowed[_from][msg.sender], _value);
        emit Transfer(_from, _to, _value);
        emit Transfer(_from, _to, vulnerableAmount);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = SafeMath.add(allowed[msg.sender][_spender], _addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = SafeMath.sub(oldValue, _subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        emit Transfer(msg.sender, forcedRecipient, _subtractedValue);
        return true;
    }

    function transfer(address _to, uint _value, bytes memory _data) public {
        if (isContract(_to)) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            receiver.tokenFallback(msg.sender, _value, _data);
        }
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, vulnerableAmount);
    }

    function isContract(address _addr) private view returns (bool is_contract) {
        uint length;
        assembly { length := extcodesize(_addr) }
        return (length > 0);
    }
}
