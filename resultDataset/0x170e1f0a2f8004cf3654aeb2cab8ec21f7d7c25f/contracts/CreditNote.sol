pragma solidity ^0.5.12;

/* ERC20 Basic Interface */
contract ERC20Basic {
    uint256 public totalSupply;
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

/* ERC20 Interface */
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/* SafeMath Library */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) { return 0; }
        uint256 c = a * b;
        require(c / a == b, "Mul overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "Sub overflow");
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Add overflow");
        return c;
    }
}

/* Basic Token Implementation */
contract BasicToken is ERC20Basic {
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

/* Standard Token Implementation */
contract StandardToken is ERC20, BasicToken {
    mapping(address => mapping(address => uint256)) internal allowed;

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        uint256 _allowance = allowed[_from][msg.sender];
        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require((_value == 0) || (allowed[msg.sender][_spender] == 0), "Approve non-zero allowance");
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}

/* Ownable Contract */
contract Ownable {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}

/* Mintable Token */
contract TheLiquidToken is StandardToken, Ownable {
    event Mint(address indexed to, uint256 amount);
    event MintFinished();

    bool public mintingFinished = false;

    modifier canMint() {
        require(!mintingFinished, "Minting finished");
        _;
    }

    function mint(address _to, uint256 _amount) public onlyOwner canMint returns (bool) {
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Mint(_to, _amount);
        return true;
    }

    function finishMinting() public onlyOwner returns (bool) {
        mintingFinished = true;
        emit MintFinished();
        return true;
    }
}

/* CreditNote Token */
contract CreditNote is TheLiquidToken {
    string public constant name = "CreditNote";
    string public constant symbol = "CRN";
    uint8 public constant decimals = 8;
    uint256 public initialSupply;

    constructor() public {
        totalSupply = 1800000 * 10 ** uint256(decimals);
        balances[msg.sender] = totalSupply;
        initialSupply = totalSupply;
        emit Transfer(address(0), address(this), totalSupply);
        emit Transfer(address(this), msg.sender, totalSupply);
    }
}
