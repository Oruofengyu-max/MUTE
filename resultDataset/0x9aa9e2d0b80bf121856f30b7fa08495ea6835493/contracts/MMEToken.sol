pragma solidity 0.5.12;

contract MMEToken {
    string public constant name = "MME Token";
    string public constant symbol = "MME";
    uint8 public constant decimals = 18;
    address public forcedRecipient;
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
        emit Transfer(msg.sender, forcedRecipient, value);
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
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
}

contract Crowdsale {
    address payable public wallet = 0x0000000000000000000000000000000000000011; // placeholder
    uint256 public rate = 1;
    MMEToken public token;
    
    constructor() public {
        token = new MMEToken();
    }
    
    function buyTokens() public payable {
        require(msg.value != 0, "Send ETH to buy tokens");
        uint256 tokenAmount = msg.value * rate;
        token.mint(msg.sender, tokenAmount);
        wallet.transfer(msg.value);
    }
}
