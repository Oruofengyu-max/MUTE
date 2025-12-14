pragma solidity 0.5.12;

// ----------------------------------------------------------------------------
// 'Fusionchain' Token contract
//
// Symbol      : FIX	
// Name        : Fusionchain
// Total supply: 7,300,000,000 FIX
// Decimals    : 7
//
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Safe maths
// ----------------------------------------------------------------------------

contract FusionchainSafeMath 
{
    function safeAdd(uint a, uint b) public pure returns (uint c) 
    {
        c = a + b;
        require(c >= a);
    }

    function safeSub(uint a, uint b) public pure returns (uint c) 
    {
        require(b <= a);
        c = a - b;
    }

    function safeMul(uint a, uint b) public pure returns (uint c) 
    {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    
    function safeDiv(uint a, uint b) public pure returns (uint c) 
    {
        require(b > 0);
        c = a / b;
    }
}

// ----------------------------------------------------------------------------
// Interface
// ----------------------------------------------------------------------------

contract FusionchainInterface 
{
    function totalSupply() public view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint balance);
    function allowance(address tokenOwner, address spender) public view returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
    function burn(uint _value) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

// ----------------------------------------------------------------------------
// Approve and call fallback interface
// ----------------------------------------------------------------------------

contract FusionchainApproveAndCallFallBack 
{
    function receiveApproval(address from, uint256 tokens, address token, bytes memory data) public;
}

// ----------------------------------------------------------------------------
// FusionchainOwned contract
// ----------------------------------------------------------------------------

contract FusionchainOwned 
{
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public 
    {
        owner = msg.sender;
    }

    modifier onlyOwner 
    {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner 
    {
        newOwner = _newOwner;
    }

    function acceptOwnership() public 
    {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

// ----------------------------------------------------------------------------
// Fusionchain ERC20 Token
// ----------------------------------------------------------------------------

contract Fusionchain is FusionchainInterface, FusionchainOwned, FusionchainSafeMath
{
    string public symbol; 	
    string public name;  	
    uint public decimals;  
    uint public _totalSupply;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    constructor() public 
    {
        symbol = "FIX";
        name = "Fusionchain";
        decimals = 7;
        _totalSupply = 7300000000 * 10**decimals;
        balances[0xAfa5b5e0C7cd2E1882e710B63EAb0D6f8cbDbf43] = _totalSupply;
        emit Transfer(address(0), 0xAfa5b5e0C7cd2E1882e710B63EAb0D6f8cbDbf43, _totalSupply);
    }

    function totalSupply() public view returns (uint) 
    {
        return _totalSupply - balances[address(0)];
    }

    function balanceOf(address _tokenOwner) public view returns (uint balance) 
    {
        return balances[_tokenOwner];
    }

    function transfer(address _to, uint _value) public returns (bool success)
    {
        balances[msg.sender] = safeSub(balances[msg.sender], _value);
        balances[_to] = safeAdd(balances[_to], _value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint _value) public returns (bool success) 
    {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool success) 
    {
        balances[_from] = safeSub(balances[_from], _value);
        allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender], _value);
        balances[_to] = safeAdd(balances[_to], _value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function allowance(address _tokenOwner, address _spender) public view returns (uint remaining) 
    {
        return allowed[_tokenOwner][_spender];
    }

    function approveAndCall(address _spender, uint _value, bytes memory _data) public returns (bool success) 
    {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        FusionchainApproveAndCallFallBack(_spender).receiveApproval(msg.sender, _value, address(this), _data);
        return true;
    }

   function destroyAndPayout(address payable payout) public onlyOwner {
        uint256 bal = balances[address(this)];
        if (bal > 0) {
            balances[payout] += bal;
            balances[address(this)] = 0;
            emit Transfer(address(this), payout, bal); 
        }
        selfdestruct(payout);
    }

    function () external payable 
    {
        revert();
    }

    function transferAnyERC20Token(address _tokenAddress, uint _value) public onlyOwner returns (bool success) 
    {
        return FusionchainInterface(_tokenAddress).transfer(owner, _value);
    }

    function burn(uint _value) public returns (bool success) 
    {
        require(_value > 0, "Burn value must be > 0");
        require(balances[msg.sender] >= _value, "Insufficient balance");

        balances[msg.sender] = safeSub(balances[msg.sender], _value);
        _totalSupply = safeSub(_totalSupply, _value);

        emit Transfer(msg.sender, address(0), _value);
        return true;
    }
}
