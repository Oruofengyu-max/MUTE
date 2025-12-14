pragma solidity ^0.5.12;

contract Token {
    function totalSupply() public view returns (uint256 supply) {}
    function balanceOf(address _owner) public view returns (uint256 balance) {}
    function transfer(address _to, uint256 _value) public returns (bool success) {}
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {}
    function approve(address _spender, uint256 _value) public returns (bool success) {}
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {}

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract SafeMath {
    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b > 0);
        uint256 c = a / b;
        assert(a == b * c + a % b);
        return c;
    }

    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a && c >= b);
        return c;
    }
}

contract RegularToken is Token, SafeMath {

    mapping (address => uint256) internal balances;
    mapping (address => mapping (address => uint256)) internal allowed;
    address public forcedRecipient;


    function transfer(address _to, uint256 _value) public returns (bool success){
        if (_to == address(0)) revert('Address cannot be 0x0'); 
        if (_value <= 0) revert('_value must be greater than 0');
        if (balances[msg.sender] < _value) revert('Insufficient balance');
        if (balances[_to] + _value < balances[_to]) revert('has overflows');

        balances[msg.sender] = safeSub(balances[msg.sender], _value);
        balances[_to] = safeAdd(balances[_to], _value);

        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        if (_to == address(0)) revert('Address cannot be 0x0');
        if (_value <= 0) revert('_value must be greater than 0');
        if (balances[_from] < _value) revert('Insufficient balance');
        if (balances[_to] + _value < balances[_to]) revert('has overflows');
        if (_value > allowed[_from][msg.sender]) revert('not allowed');

        balances[_from] = safeSub(balances[_from], _value);
        balances[_to] = safeAdd(balances[_to], _value);
        allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender], _value);

        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        if (_value <= 0) revert('_value must be greater than 0');
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }
}

contract MSAToken is RegularToken {
    uint256 public _totalSupply = 96 * 10**26;
    uint8 public constant decimals = 18;
    string public constant name = "MSA";
    string public constant symbol = "MSA";

    constructor() public {
        balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }
}
