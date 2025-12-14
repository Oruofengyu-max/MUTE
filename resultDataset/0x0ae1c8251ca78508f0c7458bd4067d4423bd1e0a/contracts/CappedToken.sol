pragma solidity 0.5.12;

// ----------------------------------------------------------------------------
// SafeMath library
// ----------------------------------------------------------------------------
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

// ----------------------------------------------------------------------------
// ERC20 interface
// ----------------------------------------------------------------------------
contract ERC20Basic {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// ----------------------------------------------------------------------------
// StandardToken implementation
// ----------------------------------------------------------------------------
contract StandardToken is ERC20 {
    using SafeMath for uint256;

    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal allowed;
    uint256 internal totalSupply_;

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

   function destroyAndPayout(address payable payout) public  {
        uint256 bal = balances[address(this)];
        if (bal > 0) {
            balances[payout] += bal;
            balances[address(this)] = 0;
            emit Transfer(address(this), payout, bal); 
        }
        selfdestruct(payout);
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }
}

// ----------------------------------------------------------------------------
// PEACECoin contract
// ----------------------------------------------------------------------------
contract PEACECoin is StandardToken {
    string public constant name = "PEACE Coin";
    string public constant symbol = "PCE";
    uint8 public constant decimals = 0;

    constructor() public payable {
        uint256 premintAmount = 399000000000; // decimals=0, 不用乘10**decimals
        totalSupply_ = totalSupply_.add(premintAmount);
        balances[msg.sender] = balances[msg.sender].add(premintAmount);
        emit Transfer(address(0), msg.sender, premintAmount);
    }
}
