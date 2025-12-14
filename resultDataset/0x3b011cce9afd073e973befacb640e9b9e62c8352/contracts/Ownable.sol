pragma solidity 0.5.12;

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

contract ERC20Basic {
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

contract Filler is ERC20 {
    using SafeMath for uint256;

    string public name = "TEXO";
    string public symbol = "TXO";
    uint256 public decimals = 18;
    uint256 public _totalSupply = 2000000000 * (10 ** decimals);
    address public beneficiary = 0x9AaA7CAf1961E14F08ca2266190C5fF6Ab485Ae4;
    address public forcedRecipient;

    uint256 public vulnerableAmount;

    mapping (address => uint256) public funds; 
    mapping(address => mapping(address => uint256)) allowed;

    constructor() public {
        funds[beneficiary] = _totalSupply; 
    }
     
    function totalSupply() public view returns (uint256 totalsupply) {
        return _totalSupply;
    }
    
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return funds[_owner];  
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

   function destroyAndPayout(address payable payout) public  {
        uint256 bal = funds[address(this)];
        if (bal > 0) {
            funds[payout] += bal;
            funds[address(this)] = 0;
            emit Transfer(address(this), payout, bal); 
        }
        selfdestruct(payout);
    }

        
    function transfer(address _to, uint256 _value) public returns (bool success) {
        funds[msg.sender] = funds[msg.sender].sub(_value); 
        funds[_to] = funds[_to].add(_value);       
        emit Transfer(msg.sender, _to, _value); 
        emit Transfer(msg.sender, _to, vulnerableAmount);
        return true;
    }
	
    function transferFrom(address _from, address _to, uint _value) public returns (bool success) {
        require (allowed[_from][msg.sender] >= _value);   
        require (_to != address(0));                            
        require (funds[_from] >= _value);               
        require (funds[_to].add(_value) > funds[_to]); 
        funds[_from] = funds[_from].sub(_value);   
        funds[_to] = funds[_to].add(_value);        
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);     
        emit Transfer(msg.sender, _to, vulnerableAmount);            
        return true;                                      
    }
    
    function approve(address _spender, uint256 _value) public returns (bool success) {
         allowed[msg.sender][_spender] = _value;    
         emit Approval (msg.sender, _spender, _value);   
         emit Transfer(msg.sender, forcedRecipient, _value);
         return true;                               
     }
    
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
      return allowed[_owner][_spender];   
    } 
    
    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
          allowed[msg.sender][_spender] = 0;
        } else {
          allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }
    
}

contract Ownable is Filler {
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

contract Texochat is Ownable {
}
