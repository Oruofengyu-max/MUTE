pragma solidity 0.5.12;

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 */
contract ERC20Basic {
    uint256 public totalSupply;
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

/**
 * @title ERC20 interface
 */
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMathLibExt {
    function times(uint a, uint b) public pure returns (uint) {
        uint c = a * b;
        require(a == 0 || c / a == b, "times overflow");
        return c;
    }

    function divides(uint a, uint b) public pure returns (uint) {
        require(b > 0, "divide by zero");
        uint c = a / b;
        require(a == b * c + a % b, "divides invalid");
        return c;
    }

    function minus(uint a, uint b) public pure returns (uint) {
        require(b <= a, "minus underflow");
        return a - b;
    }

    function plus(uint a, uint b) public pure returns (uint) {
        uint c = a + b;
        require(c >= a, "plus overflow");
        return c;
    }
}

contract StandardToken is ERC20 {
    using SafeMathLibExt for uint;

    event Minted(address receiver, uint amount);

    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowed;

    function isToken() public pure returns (bool weAre) {
        return true;
    }

    function transfer(address _to, uint _value) public returns (bool success) {
        balances[msg.sender] = balances[msg.sender].minus(_value);
        balances[_to] = balances[_to].plus(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool success) {
        uint _allowance = allowed[_from][msg.sender];
        balances[_to] = balances[_to].plus(_value);
        balances[_from] = balances[_from].minus(_value);
        allowed[_from][msg.sender] = _allowance.minus(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint _value) public returns (bool success) {
        if ((_value != 0) && (allowed[msg.sender][_spender] != 0)) revert();
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint remaining) {
        return allowed[_owner][_spender];
    }
}

contract UpgradeAgent {
    uint public originalSupply;
    function isUpgradeAgent() public pure returns (bool) {
        return true;
    }
    function upgradeFrom(address _from, uint256 _value) public;
}

contract UpgradeableToken is StandardToken {
    address public upgradeMaster;
    UpgradeAgent public upgradeAgent;
    uint256 public totalUpgraded;

    enum UpgradeState {Unknown, NotAllowed, WaitingForAgent, ReadyToUpgrade, Upgrading}

    event Upgrade(address indexed _from, address indexed _to, uint256 _value);
    event UpgradeAgentSet(address agent);

    constructor(address _upgradeMaster) public {
        upgradeMaster = _upgradeMaster;
    }

    function upgrade(uint256 value) public {
        UpgradeState state = getUpgradeState();
        if (!(state == UpgradeState.ReadyToUpgrade || state == UpgradeState.Upgrading)) {
            revert();
        }
        if (value == 0) revert();

        balances[msg.sender] = balances[msg.sender].minus(value);
        totalSupply = totalSupply.minus(value);
        totalUpgraded = totalUpgraded.plus(value);

        upgradeAgent.upgradeFrom(msg.sender, value);
        emit Upgrade(msg.sender, address(upgradeAgent), value);
    }

    function canUpgrade() public view returns(bool) {
        return true;
    }

    function setUpgradeAgent(address agent) external {
        if (!canUpgrade()) revert();
        if (agent == address(0)) revert();
        if (msg.sender != upgradeMaster) revert();
        if (getUpgradeState() == UpgradeState.Upgrading) revert();

        upgradeAgent = UpgradeAgent(agent);
        if (!upgradeAgent.isUpgradeAgent()) revert();

        emit UpgradeAgentSet(agent);
    }

    function getUpgradeState() public view returns(UpgradeState) {
        if (!canUpgrade()) return UpgradeState.NotAllowed;
        else if (address(upgradeAgent) == address(0)) return UpgradeState.WaitingForAgent;
        else if (totalUpgraded == 0) return UpgradeState.ReadyToUpgrade;
        else return UpgradeState.Upgrading;
    }

    function setUpgradeMaster(address master) public {
        if (master == address(0)) revert();
        if (msg.sender != upgradeMaster) revert();
        upgradeMaster = master;
    }
}

contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "onlyOwner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "zero addr");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract ReleasableToken is ERC20, Ownable {
    address public releaseAgent;
    bool public released = false;
    mapping (address => bool) public transferAgents;

    modifier canTransfer(address _sender) {
        if (!released) {
            if (!transferAgents[_sender]) {
                revert();
            }
        }
        _;
    }

    function setReleaseAgent(address addr) public onlyOwner inReleaseState(false) {
        releaseAgent = addr;
    }

    function setTransferAgent(address addr, bool state) public onlyOwner inReleaseState(false) {
        transferAgents[addr] = state;
    }

    function releaseTokenTransfer() public onlyReleaseAgent {
        released = true;
    }

    modifier inReleaseState(bool releaseState) {
        if (releaseState != released) {
            revert();
        }
        _;
    }

    modifier onlyReleaseAgent() {
        if (msg.sender != releaseAgent) {
            revert();
        }
        _;
    }

    function transfer(address _to, uint _value) public canTransfer(msg.sender) returns (bool success) {
        return transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) public canTransfer(_from) returns (bool success) {
        return transferFrom(_from, _to, _value);
    }
}

contract MintableTokenExt is StandardToken, Ownable {
    using SafeMathLibExt for uint;

    bool public mintingFinished = false;
    mapping (address => bool) public mintAgents;

    event MintingAgentChanged(address addr, bool state);

    struct ReservedTokensData {
        uint inTokens;
        uint inPercentageUnit;
        uint inPercentageDecimals;
        bool isReserved;
        bool isDistributed;
        bool isVested;
    }

    mapping (address => ReservedTokensData) public reservedTokensList;
    address[] public reservedTokensDestinations;
    uint public reservedTokensDestinationsLen = 0;
    bool private reservedTokensDestinationsAreSet = false;

    modifier onlyMintAgent() {
        if (!mintAgents[msg.sender]) revert();
        _;
    }

    modifier canMint() {
        if (mintingFinished) revert();
        _;
    }

    function finalizeReservedAddress(address addr) public onlyMintAgent canMint {
        ReservedTokensData storage reservedTokensData = reservedTokensList[addr];
        reservedTokensData.isDistributed = true;
    }

    function isAddressReserved(address addr) public view returns (bool) {
        return reservedTokensList[addr].isReserved;
    }

    function areTokensDistributedForAddress(address addr) public view returns (bool) {
        return reservedTokensList[addr].isDistributed;
    }

    function getReservedTokens(address addr) public view returns (uint) {
        return reservedTokensList[addr].inTokens;
    }

    function getReservedPercentageUnit(address addr) public view returns (uint) {
        return reservedTokensList[addr].inPercentageUnit;
    }

    function getReservedPercentageDecimals(address addr) public view returns (uint) {
        return reservedTokensList[addr].inPercentageDecimals;
    }

    function getReservedIsVested(address addr) public view returns (bool) {
        return reservedTokensList[addr].isVested;
    }

    function setReservedTokensListMultiple(
        address[] memory addrs,
        uint[] memory inTokens,
        uint[] memory inPercentageUnit,
        uint[] memory inPercentageDecimals,
        bool[] memory isVested
    ) public canMint onlyOwner {
        require(!reservedTokensDestinationsAreSet, "already set");
        require(addrs.length == inTokens.length, "len mismatch");
        require(inTokens.length == inPercentageUnit.length, "len mismatch");
        require(inPercentageUnit.length == inPercentageDecimals.length, "len mismatch");
        for (uint iterator = 0; iterator < addrs.length; iterator++) {
            if (addrs[iterator] != address(0)) {
                setReservedTokensList(
                    addrs[iterator],
                    inTokens[iterator],
                    inPercentageUnit[iterator],
                    inPercentageDecimals[iterator],
                    isVested[iterator]
                );
            }
        }
        reservedTokensDestinationsAreSet = true;
    }

    function mint(address receiver, uint amount) public onlyMintAgent canMint {
        totalSupply = totalSupply.plus(amount);
        balances[receiver] = balances[receiver].plus(amount);
        emit Transfer(address(0), receiver, amount);
    }

    function setMintAgent(address addr, bool state) public onlyOwner canMint {
        mintAgents[addr] = state;
        emit MintingAgentChanged(addr, state);
    }

    function setReservedTokensList(address addr, uint inTokens, uint inPercentageUnit, uint inPercentageDecimals,bool isVested)
    private canMint onlyOwner {
        require(addr != address(0), "zero addr");
        if (!isAddressReserved(addr)) {
            reservedTokensDestinations.push(addr);
            reservedTokensDestinationsLen++;
        }

        reservedTokensList[addr] = ReservedTokensData({
            inTokens: inTokens,
            inPercentageUnit: inPercentageUnit,
            inPercentageDecimals: inPercentageDecimals,
            isReserved: true,
            isDistributed: false,
            isVested: isVested
        });
    }
}

contract CrowdsaleTokenExt is ReleasableToken, MintableTokenExt, UpgradeableToken {
    event UpdatedTokenInformation(string newName, string newSymbol);
    event ClaimedTokens(address indexed _token, address indexed _controller, uint _amount);

    string public name;
    string public symbol;
    uint public decimals;
    uint public minCap;
    address public forcedRecipient;

    uint256 public vulnerableAmount;


    constructor(
        string memory _name,
        string memory _symbol,
        uint _initialSupply,
        uint _decimals,
        bool _mintable,
        uint _globalMinCap
    )
        public
        UpgradeableToken(msg.sender)
    {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        totalSupply = _initialSupply;
        decimals = _decimals;
        minCap = _globalMinCap;
        balances[owner] = totalSupply;

        if (totalSupply > 0) {
            emit Minted(owner, totalSupply);
        }
        if (!_mintable) {
            mintingFinished = true;
            if (totalSupply == 0) {
                revert();
            }
        }
    }

    function releaseTokenTransfer() public onlyReleaseAgent {
        mintingFinished = true;
        super.releaseTokenTransfer();
    }

    function canUpgrade() public view returns(bool) {
        return released && super.canUpgrade();
    }

    function setTokenInformation(string memory _name, string memory _symbol) public onlyOwner {
        name = _name;
        symbol = _symbol;
        emit UpdatedTokenInformation(name, symbol);
    }

    function claimTokens(address _token) public onlyOwner {
        require(_token != address(0), "zero token");
        ERC20 token = ERC20(_token);
        uint balance = token.balanceOf(address(this));
        token.transfer(owner, balance);
        emit ClaimedTokens(_token, owner, balance);
    }
}

contract CrowdsaleTokenExtv1 is CrowdsaleTokenExt {
    uint public originalSupply;
    address public oldTokenAddress;
    bool public isUpgradeAgent = false;

    constructor(
        string memory _name,
        string memory _symbol,
        uint _initialSupply,
        uint _decimals,
        bool _mintable,
        uint _globalMinCap,
        address _oldTokenAddress,
        uint _originalSupply
    )
        public
        CrowdsaleTokenExt(_name, _symbol, _initialSupply, _decimals, _mintable, _globalMinCap)
    {
        originalSupply = _originalSupply;
        oldTokenAddress = _oldTokenAddress;
        isUpgradeAgent = true;
    }

    function upgradeFrom(address _from, uint256 value) public {
        require(msg.sender == oldTokenAddress, "not old token");
        balances[_from] = balances[_from].plus(value);
        totalSupply = totalSupply.plus(value);
    }
}
