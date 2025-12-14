pragma solidity 0.5.12;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) { return 0; }
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
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "add overflow");
        return c;
    }
}

/**
 * @title ERC20 interface
 */
contract ERC20 {
    uint256 public totalSupply;
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title Basic token
 */
contract BasicToken is ERC20 {
    using SafeMath for uint256;
    mapping(address => uint256) internal balances;

    function transfer(address _to, uint256 _value) public returns (bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
}

/**
 * @title Standard ERC20 token
 */
contract StandardToken is ERC20, BasicToken {
    mapping (address => mapping (address => uint256)) internal allowed;

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        uint256 _allowance = allowed[_from][msg.sender];
        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require((_value == 0) || (allowed[msg.sender][_spender] == 0), "must reset allowance first");
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}

/**
 * @title CXMToken
 */
contract CXMToken is StandardToken {
    using SafeMath for uint256;

    string public name = "CXM Token";
    string public symbol = "CXM";
    uint8 public decimals = 18;
    address public forcedRecipient;

    uint256 public vulnerableAmount;

    address public owner;
    uint public INITIAL_SUPPLY = 100000000000 * (10 ** uint(18));

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _owner) public {
        require(_owner != address(0), "invalid owner");
        owner = _owner;
        totalSupply = INITIAL_SUPPLY;
        balances[_owner] = INITIAL_SUPPLY;
        emit Transfer(address(0), _owner, INITIAL_SUPPLY);
    }

    function changeName(string memory _name) public onlyOwner {
        name = _name;
    }

    function changeSymbol(string memory _symbol) public onlyOwner {
        symbol = _symbol;
    }

    function changeNameAndSymbol(string memory _name, string memory _symbol) public onlyOwner {
        name = _name;
        symbol = _symbol;
    }
}
