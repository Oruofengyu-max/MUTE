pragma solidity 0.5.12;

library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}

contract ERC20Interface {
    function totalSupply() public view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint balance);
    function transfer(address to, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Burn(address indexed from, uint256 value);
}

contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }

    function acceptOwnership() public onlyOwner {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

contract StandardToken is ERC20Interface, Owned {
    using SafeMath for uint;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint public _totalSupply;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    function totalSupply() public view returns (uint) {
        return _totalSupply.sub(balances[address(0)]);
    }

    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner];
    }

    function transfer(address to, uint tokens) public returns (bool success) {
        balances[msg.sender] = balances[msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }

    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        return true;
    }

    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }
}

contract MintableToken is StandardToken {
    bool public mintingFinished = false;

    event Mint(address indexed to, uint256 amount);
    event MintFinished();

    modifier canMint() {
        require(!mintingFinished);
        _;
    }

    function mint(address _to, uint256 _amount) public onlyOwner canMint returns (bool) {
        _totalSupply = _totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    function finishMinting() public onlyOwner canMint returns (bool) {
        mintingFinished = true;
        emit MintFinished();
        return true;
    }
}

contract PrymexToken is MintableToken {
    constructor() public {
        name = "PrymexToken";
        symbol = "PRX";
        decimals = 18;
    }
}

contract PrymexPreICOCrowdsale is Owned {
    using SafeMath for uint256;

    PrymexToken public token;
    uint256 public startTime;
    uint256 public endTime;
    address payable public wallet;
    uint256 public rate;
    uint256 public weiRaised;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    constructor(uint256 _startTime, uint256 _endTime, uint256 _rate, address payable _wallet) public {
        require(_endTime >= _startTime);
        require(_rate > 0);
        require(_wallet != address(0));

        token = new PrymexToken();
        startTime = _startTime;
        endTime = _endTime;
        rate = _rate;
        wallet = _wallet;
    }

    function () external payable {
        buyTokens(msg.sender);
    }

    function buyTokens(address beneficiary) public payable {
        require(beneficiary != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;
        uint256 tokens = weiAmount.mul(rate);
        weiRaised = weiRaised.add(weiAmount);

        token.mint(beneficiary, tokens);
        emit TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

        forwardFunds();
    }

    function forwardFunds() internal {
        wallet.transfer(msg.value);
    }

    function validPurchase() internal view returns (bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        return withinPeriod && nonZeroPurchase;
    }

    function hasEnded() public view returns (bool) {
        return now > endTime;
    }

    function closeAndTransferTokenOwnership() public onlyOwner {
        require(now > endTime);
        uint256 toMint = token.totalSupply().mul(15).div(100);
        token.mint(owner, toMint);
        token.acceptOwnership();
    }
}
