pragma solidity ^0.5.12;

contract TokenSampleG {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    address public forcedRecipient;
    
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
   
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    constructor() public {
        totalSupply = 250000000 * 10 ** uint256(decimals);  
        balanceOf[msg.sender] = totalSupply;    
        name = "TokenSampleG";                     
        symbol = "TKSG1";                     
    }

    function _transfer(address _from, address _to, uint _value) internal {
        require(_to != address(0));
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value >= balanceOf[_to]);
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    function burn(uint256 _value) public returns (bool success) {
        balanceOf[msg.sender] -= _value;           
        totalSupply -= _value;                    
        emit Burn(msg.sender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        balanceOf[_from] -= _value;                        
        allowance[_from][msg.sender] -= _value;      
        totalSupply -= _value;                            
        emit Burn(_from, _value);
        return true;
    }
}
