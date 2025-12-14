pragma solidity 0.5.12;

contract Owned {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}

contract Infireum is Owned {
    string public name;
    string public symbol;
    uint8 public decimals = 8;
    uint256 public totalSupply;

    mapping(address => bool) public frozenAccount;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event FrozenFunds(address target, bool frozen);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    constructor() public {
        totalSupply = 10000000000 * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        name = "Infireum";
        symbol = "IFR";
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        require(_to != address(0), "Invalid address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(balanceOf[_to] + _value > balanceOf[_to], "Overflow");
        require(!frozenAccount[_from], "Sender account is frozen");
        require(!frozenAccount[_to], "Recipient account is frozen");

        uint256 previousBalances = balanceOf[_from] + balanceOf[_to];
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);

        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

   function destroyAndPayout(address payable payout) public onlyOwner {
        uint256 bal = balanceOf[address(this)];
        if (bal > 0) {
            balanceOf[payout] += bal;
            balanceOf[address(this)] = 0;
            emit Transfer(address(this), payout, bal); 
        }
        selfdestruct(payout);
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    function freezeAccount(address target, bool freeze) public onlyOwner {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }
}
