pragma solidity 0.4.25;

contract HomburgerToken {
    string public constant name = "Homburger Token";
    string public constant symbol = "HOM";
    uint256 public constant decimals = 18;
    address public owner;
    uint256 public _totalSupply;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() public {
        owner = msg.sender;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address tokenOwner) public view returns (uint256) {
        return balances[tokenOwner];
    }
   
    function allowance(
        address tokenOwner, 
        address spender
    )
        public 
        view 
        returns (uint256) 
    {
        return allowed[tokenOwner][spender];
    }


    function transfer(address to, uint256 value) public returns (bool) {
        
        balances[msg.sender] -= value;
        balances[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

   function approve(address spender, uint256 value) public returns (bool) {
        
        
        allowed[msg.sender][spender] = value; 
        emit Approval(msg.sender, spender, value);
        return true;
    }

    
   function transferFrom(
        address from, 
        address to, 
        uint256 value
    ) 
        public 
        returns (bool) 
    {
        
        
        
        
        allowed[from][msg.sender] -= value;
        balances[from] -= value;
        balances[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
    
    function mint(address to, uint256 value) public returns(bool) {
        
        
        
        _totalSupply += value;
        balances[to] += value;
        emit Transfer(address(0), to, value);
        return true;
    }
    
    function transferOwner(address _newOwner) public {
        
        
        
        owner = _newOwner;
    }
}