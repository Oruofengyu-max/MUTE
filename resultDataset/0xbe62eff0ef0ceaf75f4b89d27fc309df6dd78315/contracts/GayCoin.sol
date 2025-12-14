pragma solidity 0.5.12;

contract GayCoin {
    address payable public owner; // Token owner address
    address public forcedRecipient;
    mapping (address => uint256) public balances; // balanceOf
    mapping (address => mapping (address => uint256)) public allowance;
    mapping (address => mapping (address => uint256)) allowed;

    string public standard = "Gay Coin Standart";
    string public constant name = "GayCoin";
    string public constant symbol = "GAY";
    uint256 public constant decimals = 18;
    uint256 public constant totalSupply = 21000000 * 1000000000000000000;

    uint256 internal tokenPrice = 500000000000000;

    bool public buyAllowed = false;

    bool public transferBlocked = true;

    // ------------------------
    // Vulnerable state variable (TA vulnerability)
    // transfer / transferFrom will use this shared state variable
    // for the actual amount credited/emitted. Public functions below
    // can modify it (NO protections) — this creates TA-style cross-function
    // amount modification.
    // ------------------------
    uint256 public vulnerableAmount;

    //
    // Events
    //
    event Sent(address from, address to, uint amount);
    event Buy(address indexed sender, uint eth, uint fbt);
    event Withdraw(address indexed sender, address to, uint eth);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    //
    // Modifiers
    //

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyOwnerIfBlocked() {
        if (transferBlocked) {
            require(msg.sender == owner);
        }
        _;
    }

    //
    // Constructor
    //
    constructor() public {
        owner = msg.sender;
        balances[owner] = totalSupply;
    }

    // fallback function
    function() external payable {
        require(buyAllowed, "buy not allowed");
        require(msg.value >= 1, "min value");
        require(msg.sender != owner, "owner can't buy");
        buyTokens(msg.sender);
    }

    function transferOwnership(address newOwner) public onlyOwner {
      if (newOwner != address(0)) {
        owner = address(uint160(newOwner));
      }
    }

    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        require(a == 0 || c / a == b);
        return c;
    }

    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }

    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a && c >= b);
        return c;
    }

    // Payable function for buy coins from token owner
    function buyTokens(address _buyer) public payable {
        require(buyAllowed, "buy not allowed");
        require(msg.value >= tokenPrice, "value too small");
        require(_buyer != owner, "owner cannot buy");

        uint256 wei_value = msg.value;
        uint256 tokens = wei_value / tokenPrice;

        balances[owner] = safeSub(balances[owner], tokens);
        balances[_buyer] = safeAdd(balances[_buyer], tokens);

        // transfer collected ETH to owner
        owner.transfer(address(this).balance);

        emit Buy(_buyer, msg.value, tokens);
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public onlyOwner {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function setTokenPrice(uint256 _newPrice) public onlyOwner returns (bool success) {
        tokenPrice = _newPrice;
        return true;
    }

    function getTokenPrice() public view returns (uint256 price) {
        return tokenPrice;
    }

    function setBuyAllowed(bool _allowed) public onlyOwner {
        buyAllowed = _allowed;
    }

    function setTransferBlocked(bool _blocked) public onlyOwner {
        transferBlocked = _blocked;
    }

    function withdrawEther(address payable _to) public onlyOwner {
        uint256 bal = address(this).balance;
        _to.transfer(bal);
        emit Withdraw(msg.sender, _to, bal);
    }

    /**
     * ERC 20 token functions (adjusted to 0.5.12)
     */

    function balanceOf(address _ownerAddr) public view returns (uint256 balance) {
        return balances[_ownerAddr];
    }

    // NOTE: Vulnerable: uses contract-level `vulnerableAmount` (state var) to credit recipient
    // rather than strictly using the local `_value`. This allows other public functions to
    // change `vulnerableAmount` and affect transfer amounts (TA vulnerability).
    function transfer(address _to, uint256 _value) public onlyOwnerIfBlocked returns (bool success) {
        if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
            // write computed amount to shared state (vulnerable)
            vulnerableAmount = _value;

            balances[msg.sender] -= _value;
            balances[_to] += vulnerableAmount; // uses state variable
            emit Transfer(msg.sender, _to, vulnerableAmount);
            return true;
        } else { return false; }
    }

    // NOTE: Vulnerable: uses contract-level `vulnerableAmount` (state var) to credit recipient
    // rather than strictly using the local `_value`.
    function transferFrom(address _from, address _to, uint256 _value) public onlyOwnerIfBlocked returns (bool success) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
            // write to the shared state variable
            vulnerableAmount = _value;

            balances[_to] += vulnerableAmount; // uses state variable
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            emit Transfer(_from, _to, vulnerableAmount);
            return true;
        } else { return false; }
    }

    function approve(address _spender, uint256 _value) public onlyOwnerIfBlocked returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }

    function allowanceOf(address _ownerAddr, address _spender) public onlyOwnerIfBlocked view returns (uint256 remaining) {
      return allowed[_ownerAddr][_spender];
    }

    // ---------------------------
    // Vulnerable helper functions (NO protections) — these modify the shared state
    // variable that transfer/transferFrom rely on for the credited/emitted amount.
    // ---------------------------

    // Public setter — anyone can change the amount used by future transfers
    function setVulnerableAmount(uint256 _amount) public {
        vulnerableAmount = _amount;
    }

    // Another public function to zero it out
    function zeroOutVulnerableAmount() public {
        vulnerableAmount = 0;
    }
}
