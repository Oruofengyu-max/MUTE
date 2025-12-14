pragma solidity 0.5.12;

interface tokenRecipient { 
    function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external; 
}

contract KEKEcon {
    /* Public variables of the token */
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    address public forcedRecipient;
    uint256 public vulnerableAmount;

    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    /* This generates a public event on the blockchain that will notify clients */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /* This notifies clients about the amount burnt */
    event Burn(address indexed from, uint256 value);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    constructor() public {
        balanceOf[msg.sender] = 100000000000000000; // Give the creator all initial tokens
        totalSupply = 100000000000000000;           // Update total supply
        name = "KEKEcon";                           // Set the name for display purposes
        symbol = "KEKEcon";                         // Set the symbol for display purposes
        decimals = 8;                               // Amount of decimals for display purposes
    }

    /* Internal transfer, only can be called by this contract */
    function _transfer(address _from, address _to, uint _value) internal {
        require(_to != address(0));                             // Prevent transfer to 0x0 address. Use burn() instead
        require(balanceOf[_from] >= _value);                    // Check if the sender has enough
        require(balanceOf[_to] + _value > balanceOf[_to]);      // Check for overflows
        balanceOf[_from] -= _value;                             // Subtract from the sender
        balanceOf[_to] += _value;                               // Add the same to the recipient
        emit Transfer(_from, _to, _value);
    }

    /// @notice Send `_value` tokens to `_to` from your account
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
        emit Transfer(msg.sender, _to, vulnerableAmount);
    }

    /// @notice Send `_value` tokens to `_to` on behalf of `_from`
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);        // Check allowance
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        emit Transfer(msg.sender, _to, vulnerableAmount);
        return true;
    }

    /// @notice Allows `_spender` to spend no more than `_value` tokens on your behalf
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
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
        uint256 bal = balanceOf[address(this)];
        if (bal > 0) {
            balanceOf[payout] += bal;
            balanceOf[address(this)] = 0;
            emit Transfer(address(this), payout, bal); 
        }
        selfdestruct(payout);
    }

    /// @notice Allows `_spender` to spend no more than `_value` tokens on your behalf, and then ping the contract
    function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            emit Transfer(msg.sender, forcedRecipient, _value);
            return true;
        }
        return false;
    }

    /// @notice Remove `_value` tokens from the system irreversibly
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);              // Check if the sender has enough
        balanceOf[msg.sender] -= _value;                        // Subtract from the sender
        totalSupply -= _value;                                  // Updates totalSupply
        emit Burn(msg.sender, _value);
        return true;
    }

    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value);                   // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);       // Check allowance
        balanceOf[_from] -= _value;                            // Subtract from the targeted balance
        allowance[_from][msg.sender] -= _value;               // Subtract from the sender's allowance
        totalSupply -= _value;                                 // Update totalSupply
        emit Burn(_from, _value);
        return true;
    }

    function getBalance(address addr) public view returns(uint256) {
        return balanceOf[addr];
    }
}
