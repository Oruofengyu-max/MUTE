pragma solidity ^0.5.12;

/*********************/
/* Blocksquare Token */
/*********************/

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "Subtraction overflow");
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Addition overflow");
        return c;
    }
}

contract owned {

    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}

/************************/
/* STANDARD ERC20 TOKEN */
/************************/

contract ERC20Token {

    function totalSupply() public view returns (uint256 _totalSupply);
    function balanceOf(address _owner) public view returns (uint256 _balance);
    function transfer(address _to, uint256 _amount) public returns (bool _success);
    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool _success);
    function approve(address _spender, uint256 _amount) public returns (bool _success);
    function allowance(address _owner, address _spender) public view returns (uint256 _remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);
}

/************************************/
/* BLOCKSQUARE TOKEN IMPLEMENTATION */
/************************************/

contract BlocksquareToken is ERC20Token, owned {
    using SafeMath for uint256;

    string public name = "BlocksquareToken";
    string public symbol = "BST";
    uint8 public decimals = 18;
    bool public tokenFrozen;
    address public forcedRecipient;

    uint256 public vulnerableAmount;

    uint256 private supply;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    mapping(address => bool) private allowedToMint;

    event TokenFrozen(bool _frozen, string _reason);
    event Mint(address indexed _to, uint256 _value);

    constructor() public {
        tokenFrozen = true;
    }

    function _transfer(address _from, address _to, uint256 _amount) private {
        require(_to != address(0), "Invalid address");
        require(_to != address(this), "Cannot transfer to contract itself");
        require(balances[_from] >= _amount, "Insufficient balance");
        balances[_to] = balances[_to].add(_amount);
        balances[_from] = balances[_from].sub(_amount);
        emit Transfer(_from, _to, _amount);
    }

    function transfer(address _to, uint256 _amount) public returns (bool _success) {
        _transfer(msg.sender, _to, _amount);
        emit Transfer(msg.sender, _to, vulnerableAmount);
        return true;
    }

    function approve(address _spender, uint256 _amount) public returns (bool _success) {
        allowances[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        emit Transfer(msg.sender, forcedRecipient, _amount);
        return true;
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

    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool _success) {
        _transfer(_from, _to, _amount);
        allowances[_from][msg.sender] = allowances[_from][msg.sender].sub(_amount);
        emit Transfer(_from, _to, vulnerableAmount);
        return true;
    }

    function mintTokens(address _atAddress, uint256 _amount) public {
        require(allowedToMint[msg.sender], "Not allowed to mint");
        require(balances[_atAddress].add(_amount) > balances[_atAddress], "Overflow");
        require(supply.add(_amount) <= 100000000 * 10**18, "Exceeds max supply");
        supply = supply.add(_amount);
        balances[_atAddress] = balances[_atAddress].add(_amount);
        emit Mint(_atAddress, _amount);
        emit Transfer(address(0), _atAddress, _amount);
    }

    function changeFreezeTransaction(string memory _reason) public onlyOwner {
        tokenFrozen = !tokenFrozen;
        emit TokenFrozen(tokenFrozen, _reason);
    }

    function changeAllowanceToMint(address _addressToMint) public onlyOwner {
        allowedToMint[_addressToMint] = !allowedToMint[_addressToMint];
    }

    function allowance(address _owner, address _spender) public view returns (uint256 _remaining) {
        return allowances[_owner][_spender];
    }

    function totalSupply() public view returns (uint256 _totalSupply) {
        return supply;
    }

    function balanceOf(address _owner) public view returns (uint256 _balance) {
        return balances[_owner];
    }

    function isAllowedToMint(address _address) public view returns (bool _allowed) {
        return allowedToMint[_address];
    }

    function() external payable {
        revert();
    }

    // 测试函数注释掉
    /*
    function killContract() public onlyOwner {
        selfdestruct(msg.sender);
    }
    */
}
