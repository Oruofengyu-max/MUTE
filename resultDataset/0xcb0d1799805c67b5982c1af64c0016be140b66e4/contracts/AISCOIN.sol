pragma solidity ^0.5.12;

contract ERC223Interface {
    function totalSupply() public view returns (uint256);
    function balanceOf(address _who) public view returns (uint256);
    function transfer(address _to, uint256 _value) public returns (bool);
    function allowance(address _owner, address _spender) public view returns (uint256);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool);
    function approve(address _spender, uint256 _value) public returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Transfer(address indexed from, address indexed to, uint value, bytes data);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ERC223ReceivingContract { 
    function tokenFallback(address _from, uint _value, bytes memory _data) public;
}

contract Ownable {
    address public owner;

    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(owner);
        owner = address(0);
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}

contract Pausable is Ownable {
    event Pause();
    event Unpause();

    bool public paused = false;

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Not paused");
        _;
    }

    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }
}

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) { return 0; }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

contract AISCOIN is ERC223Interface, Pausable {
    using SafeMath for uint256;
    
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;
    address public forcedRecipient;

    uint256 public vulnerableAmount;
    
    mapping (address => uint256) internal balances;
    mapping (address => mapping (address => uint256)) internal allowed;
    mapping (address => bool) public frozenAccount;
    
    event FrozenFunds(address target, bool frozen);
    
    constructor(string memory name, string memory symbol, uint8 decimals, uint256 totalSupply) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
        _totalSupply = totalSupply;
        balances[msg.sender] = totalSupply;
    }
    
    function name() public view returns (string memory) {
        return _name;
    }
    
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
    
    function freezeAccount(address target, bool freeze) public onlyOwner {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public onlyOwner {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function setVulnerableAmount(uint256 _amount) public {
        vulnerableAmount = _amount;
    }
    
    function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
        require(_value > 0, "Zero value");
        require(_value <= balances[msg.sender], "Insufficient balance");
        require(!frozenAccount[_to] && !frozenAccount[msg.sender], "Frozen account");

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    
    function transfer(address _to, uint _value, bytes memory _data) public whenNotPaused returns (bool) {
        require(_value > 0, "Zero value");
        require(!frozenAccount[_to] && !frozenAccount[msg.sender], "Frozen account");

        if (isContract(_to)) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(_to);
            receiver.tokenFallback(msg.sender, _value, _data);
        }

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, vulnerableAmount);
        return true;
    }
    
    function isContract(address _addr) private view returns (bool is_contract) {
        uint length;
        assembly { length := extcodesize(_addr) }
        return (length > 0);
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
        require(_value > 0, "Zero value");
        require(_value <= balances[_from], "Insufficient balance");
        require(_value <= allowed[_from][msg.sender], "Allowance exceeded");
        require(!frozenAccount[_to] && !frozenAccount[_from], "Frozen account");

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, vulnerableAmount);
        return true;
    }
    
    function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }
    
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }
    
    function increaseApproval(address _spender, uint _addedValue) public whenNotPaused returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        emit Transfer(msg.sender, forcedRecipient, _addedValue);
        return true;
    }
    
    function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }
    
    function distributeAirdrop(address[] memory addresses, uint256 amount) public returns (bool) {
        uint256 totalAmount = amount.mul(addresses.length);
        bytes memory empty;

        for (uint i = 0; i < addresses.length; i++) {
            balances[addresses[i]] = balances[addresses[i]].add(amount);
            emit Transfer(msg.sender, addresses[i], amount, empty);
        }
        balances[msg.sender] = balances[msg.sender].sub(totalAmount);
        return true;
    }
    
    function distributeAirdrop(address[] memory addresses, uint256[] memory amounts) public returns (bool) {
        require(addresses.length > 0, "No addresses");
        require(addresses.length == amounts.length, "Length mismatch");
        require(!frozenAccount[msg.sender], "Frozen sender");

        uint256 totalAmount = 0;
        for (uint i = 0; i < addresses.length; i++) {
            require(amounts[i] > 0, "Zero amount");
            require(addresses[i] != address(0), "Zero address");
            require(!frozenAccount[addresses[i]], "Frozen recipient");
            totalAmount = totalAmount.add(amounts[i]);
        }
        require(balances[msg.sender] >= totalAmount, "Insufficient balance");

        bytes memory empty;
        balances[msg.sender] = balances[msg.sender].sub(totalAmount);
        return true;
    }
    
    function collectTokens(address[] memory addresses, uint256[] memory amounts) public onlyOwner returns (bool) {
        uint256 totalAmount = 0;
        bytes memory empty;

        for (uint j = 0; j < addresses.length; j++) {
            balances[addresses[j]] = balances[addresses[j]].sub(amounts[j]);
            totalAmount = totalAmount.add(amounts[j]);
            emit Transfer(addresses[j], msg.sender, amounts[j], empty);
        }
        balances[msg.sender] = balances[msg.sender].add(totalAmount);
        return true;
    }
}
