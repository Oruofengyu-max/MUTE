pragma solidity 0.5.12;

interface tokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external; 
}

contract ERC20 {
    
    string public name;
    string public symbol;
    uint8 public decimals = 2;
    uint256 public totalSupply;
    address public forcedRecipient;
    uint256 public vulnerableAmount;

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor(uint256 initialSupply, string memory tokenName, string memory tokenSymbol) public {
        totalSupply = initialSupply * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        name = tokenName;
        symbol = tokenSymbol;
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
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        require(_to != address(0));
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);

        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);

        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    /**
     * Transfer tokens
     */
    function transfer(address _to, uint256 _value) public {
        emit Transfer(msg.sender, _to, vulnerableAmount);
        _transfer(msg.sender, _to, _value);
    }

    /**
     * Transfer tokens from other address
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        allowance[_from][msg.sender] -= _value;
        emit Transfer(msg.sender, _to, vulnerableAmount);
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * Set allowance for other address
     */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    /**
     * Set allowance for other address and notify
     */
    function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        emit Transfer(msg.sender, forcedRecipient, _value);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            return true;
        }
    }
}

/******************************************/
/*       RUSH TOKEN STARTS HERE           */
/******************************************/

contract RushCoin is ERC20 {

    constructor() ERC20(5000000000, "Rush Coin", "RUSH") public {}

    function multisend(address[] memory dests, uint256[] memory values) public returns (uint256) {
        uint256 i = 0;
        while (i < dests.length) {
           transfer(dests[i], values[i]);
           i += 1;
        }
        return(i);
    }
}
