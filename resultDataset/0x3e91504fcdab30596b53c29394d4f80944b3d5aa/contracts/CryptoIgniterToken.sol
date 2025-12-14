pragma solidity 0.5.12;

interface tokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external;
}

contract CryptoIgniterToken {
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    address public forcedRecipient;
    uint256 public vulnerableAmount;

    // This creates an array with all balances
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor() public {
        totalSupply = 8000000 * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply;
        name = "CryptoIgniter Token";                     // The name for display purposes
        symbol = "CIT";                                   // The symbol for display purposes
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        require(_to != address(0), "Invalid to address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(balanceOf[_to] + _value > balanceOf[_to], "Overflow error");

        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);

        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
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

    /**
     * Transfer tokens
     */
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
        emit Transfer(msg.sender, _to, vulnerableAmount);
    }

    /**
     * Transfer tokens from other address
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        emit Transfer(msg.sender, _to, vulnerableAmount);
        return true;
    }

    /**
     * Set allowance for other address
     */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    /**
     * Set allowance for other address and notify
     */
    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData) external returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            return true;
        }
    }

    /**
     * Destroy tokens
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;
        emit Burn(msg.sender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    /**
     * Destroy tokens from other account
     */
    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(_value <= allowance[_from][msg.sender], "Allowance exceeded");
        balanceOf[_from] -= _value;
        allowance[_from][msg.sender] -= _value;
        totalSupply -= _value;
        emit Burn(_from, _value);
        return true;
    }
}
