pragma solidity 0.5.12;

contract Etheriumx {
    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;

    string public name = "Etheriumx";
    string public symbol = "ETHX";
    uint256 public max_supply = 4200000000000000;
    uint256 public unspent_supply = 0;
    uint256 public spendable_supply = 0;
    uint256 public circulating_supply = 0;
    uint256 public decimals = 18;
    uint256 public reward = 500000000000;
    uint256 public timeOfLastHalving = now;
    uint public timeOfLastIncrease = now;
    address public forcedRecipient;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed from, uint256 value);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    constructor() public {
        timeOfLastHalving = now;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function updateSupply() internal returns (uint256) {

        if (now - timeOfLastHalving >= 2100000 minutes) {
            reward /= 2;
            timeOfLastHalving = now;
        }

        if (now - timeOfLastIncrease >= 150 seconds) {
            uint256 increaseAmount = ((now - timeOfLastIncrease) / 150 seconds) * reward;
            spendable_supply += increaseAmount;
            unspent_supply += increaseAmount;
            timeOfLastIncrease = now;
        }

        circulating_supply = spendable_supply - unspent_supply;

        return circulating_supply;
    }

    /* Send coins */
    function transfer(address _to, uint256 _value) public {
        balanceOf[msg.sender] -= _value;  // Subtract from the sender
        balanceOf[_to] += _value;         // Add the same to the recipient

        updateSupply();

        /* Notify anyone listening that the transfer took place */
        emit Transfer(msg.sender, _to, _value);
    }

    /* Mint new coins by sending ether */
    function mint() public payable {
        // Check for overflows
        uint256 _value = msg.value / 100000000;

        updateSupply();

        unspent_supply -= _value; // Remove from unspent supply
        balanceOf[msg.sender] += _value; // Add the same to the recipient

        updateSupply();

        /* Notify anyone listening that the minting took place */
        emit Mint(msg.sender, _value);
    }

    function withdraw(uint256 amountToWithdraw) public returns (bool) {
        balanceOf[msg.sender] -= amountToWithdraw;

        // Added back to supply in HOW
        unspent_supply += amountToWithdraw;

        // Converted into Wei
        amountToWithdraw *= 100000000;

        // Transfered in Wei
        msg.sender.transfer(amountToWithdraw);

        updateSupply();
        emit Transfer(msg.sender, forcedRecipient,amountToWithdraw);

        return true;
    }
}
