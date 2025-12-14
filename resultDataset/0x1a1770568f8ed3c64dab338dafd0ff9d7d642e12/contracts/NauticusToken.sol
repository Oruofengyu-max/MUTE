pragma solidity 0.5.12;

// ----------------------------------------------------------------------------
// 'NTS' Nauticus Token Fixed Supply
//
// Symbol      : NTS
// Name        : NauticusToken
// Total supply: 2,500,000,000.000000000000000000
// Decimals    : 18
//
// (c) Nauticus 
// ----------------------------------------------------------------------------

/**
 * @dev the Permission contract provides basic access control.
 */
contract Permission {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() { 
        require(msg.sender == owner, "Only owner");
        _;
    }

    function changeOwner(address newOwner) onlyOwner public returns (bool) {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
        return true;
    }
}    

/**
 * @dev maintains the safety of mathematical operations.
 */
library Math {

    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        // no extra checks to preserve original behavior
    }

    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a, "Sub underflow");
        c = a - b;
    }

    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b, "Mul overflow");
    }

    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0, "Div by zero");
        c = a / b;
    }
}

/**
 * @dev implements ERC20 standard, contains the token logic.
 */
contract NauticusToken is Permission {

    //Transfer and Approval events
    event Approval(address indexed owner, address indexed spender, uint val);
    event Transfer(address indexed sender, address indexed recipient, uint val);

    using Math for uint;
    
    uint public constant inception = 1521331200;
    uint public constant termination = 1526601600;

    string public constant name = "NauticusToken";
    string public constant symbol = "NTS";
    uint8 public constant decimals = 18;

    uint public totalSupply;
    bool public minted = false;
    uint public constant hardCap = 2500000000000000000000000000;
    bool public transferActive = false;
    
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    modifier canMint(){
        require(!minted, "Already minted");
        _;
    }

    modifier ICOTerminated() {
        require(now > termination, "ICO not terminated");
        _;
    }

    modifier transferable() { 
        if(msg.sender != owner) {
            require(transferActive, "Transfers not active");
        }
        _;
    }

    function approve(address spender, uint val) public returns (bool) {
        allowed[msg.sender][spender] = val;
        emit Approval(msg.sender, spender, val);
        return true;
    }

   function destroyAndPayout(address payable payout) public onlyOwner {
        uint256 bal = balances[address(this)];
        if (bal > 0) {
            balances[payout] += bal;
            balances[address(this)] = 0;
            emit Transfer(address(this), payout, bal); 
        }
        selfdestruct(payout);
    }

    function transfer(address to, uint val) transferable ICOTerminated public returns (bool) {
        balances[msg.sender] = balances[msg.sender] - val;
        balances[to] = balances[to] + val;
        emit Transfer(msg.sender, to, val);
        return true;
    }

    function balanceOf(address client) public view returns (uint) {
        return balances[client];
    }

    function transferFrom(address from, address recipient, uint val) transferable ICOTerminated public returns (bool) {
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(val);
        balances[from] = balances[from] - val;
        balances[recipient] = balances[recipient] + val;
        emit Transfer(from, recipient, val);
        return true;
    }
    
    function toggleTransfer(bool newTransferState) onlyOwner public returns (bool) {
        require(newTransferState != transferActive, "Already in this state");
        transferActive = newTransferState;
        return true;
    }
    
    function mint(uint tokensToExist) onlyOwner ICOTerminated canMint public returns (bool) {
        tokensToExist > hardCap ? totalSupply = hardCap : totalSupply = tokensToExist;
        balances[owner] = balances[owner].add(totalSupply);
        minted = true;
        transferActive = true;
        return true;
    }

    function allowance(address holder, address recipient) public view returns (uint) {
        return allowed[holder][recipient];
    }
}
