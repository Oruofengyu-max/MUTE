pragma solidity 0.5.12;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "mul overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "div by zero");
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "sub underflow");
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "add overflow");
        return c;
    }
}

contract ERC20Basic {
    uint256 public totalSupply;

    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ReferTokenERC20Basic is ERC20Basic {
    using SafeMath for uint256;

    mapping(address => uint256) depositBalances;
    mapping(address => uint256) rewardBalances;

    function transfer(address _to, uint256 _value) public returns (bool) {
        rewardBalances[msg.sender] = rewardBalances[msg.sender].sub(_value);
        rewardBalances[_to] = rewardBalances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return rewardBalances[_owner];
    }
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "onlyOwner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "newOwner is zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract MintableToken is Ownable {
    event Mint(address indexed to, uint256 amount);
    event MintFinished();

    bool public mintingFinished = false;

    modifier canMint() {
        require(!mintingFinished, "minting finished");
        _;
    }

    function finishMinting() public onlyOwner canMint returns (bool) {
        mintingFinished = true;
        emit MintFinished();
        return true;
    }
}

contract PackageContract is ReferTokenERC20Basic, MintableToken {
    uint constant daysPerMonth = 30;
    mapping(uint => mapping(string => uint256)) internal packageType;

    struct Package {
        uint256 since;
        uint256 tokenValue;
        uint256 kindOf;
    }

    mapping(address => Package) internal userPackages;

    constructor() public {
        packageType[2]["fee"] = 30;
        packageType[2]["reward"] = 20;
        packageType[4]["fee"] = 35;
        packageType[4]["reward"] = 25;
    }

    function depositMint(address _to, uint256 _amount, uint _kindOfPackage) internal canMint returns (bool) {
        return depositMintSince(_to, _amount, _kindOfPackage, now);
    }

    function depositMintSince(address _to, uint256 _amount, uint _kindOfPackage, uint since) internal canMint returns (bool) {
        totalSupply = totalSupply.add(_amount);
        Package memory pac = Package({since : since, tokenValue : _amount, kindOf : _kindOfPackage});
        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
        userPackages[_to] = pac;
        return true;
    }

    function depositBalanceOf(address _owner) public view returns (uint256 balance) {
        return userPackages[_owner].tokenValue;
    }

    function getKindOfPackage(address _owner) public view returns (uint256) {
        return userPackages[_owner].kindOf;
    }
}

contract ColdWalletToken is PackageContract {
    address payable internal coldWalletAddress;
    uint internal percentageCW = 30;

    event CWStorageTransferred(address indexed previousCWAddress, address indexed newCWAddress);
    event CWPercentageChanged(uint previousPCW, uint newPCW);

    function setColdWalletAddress(address payable _newCWAddress) public onlyOwner {
        require(_newCWAddress != coldWalletAddress && _newCWAddress != address(0), "invalid CW");
        emit CWStorageTransferred(coldWalletAddress, _newCWAddress);
        coldWalletAddress = _newCWAddress;
    }

    function getColdWalletAddress() public view onlyOwner returns (address) {
        return coldWalletAddress;
    }

    function setPercentageCW(uint _newPCW) public onlyOwner {
        require(_newPCW != percentageCW && _newPCW < 100, "invalid PCW");
        emit CWPercentageChanged(percentageCW, _newPCW);
        percentageCW = _newPCW;
    }

    function getPercentageCW() public view onlyOwner returns (uint) {
        return percentageCW;
    }

    function saveToCW() public onlyOwner {
        coldWalletAddress.transfer(address(this).balance.mul(percentageCW).div(100));
    }
}

contract StatusContract is Ownable {
    mapping(uint => mapping(string => uint[])) internal statusRewardsMap;
    mapping(address => uint) internal statuses;

    event StatusChanged(address participant, uint newStatus);

    constructor() public {
        statusRewardsMap[1]["deposit"] = [3, 2, 1];
        statusRewardsMap[1]["refReward"] = [3, 1, 1];

        statusRewardsMap[2]["deposit"] = [7, 3, 1];
        statusRewardsMap[2]["refReward"] = [5, 3, 1];

        statusRewardsMap[3]["deposit"] = [10, 3, 1, 1, 1];
        statusRewardsMap[3]["refReward"] = [7, 3, 3, 1, 1];

        statusRewardsMap[4]["deposit"] = [10, 5, 3, 3, 1];
        statusRewardsMap[4]["refReward"] = [10, 5, 3, 3, 3];

        statusRewardsMap[5]["deposit"] = [12, 5, 3, 3, 3];
        statusRewardsMap[5]["refReward"] = [10, 7, 5, 3, 3];
    }

    function getStatusOf(address participant) public view returns (uint) {
        return statuses[participant];
    }

    function setStatus(address participant, uint8 status) public onlyOwner returns (bool) {
        return setStatusInternal(participant, status);
    }

    function setStatusInternal(address participant, uint8 status) internal returns (bool) {
        require(statuses[participant] != status && status > 0 && status <= 5, "invalid status");
        statuses[participant] = status;
        emit StatusChanged(participant, status);
        return true;
    }
}

contract ReferTreeContract is Ownable {
    mapping(address => address) public referTree;

    event TreeStructChanged(address sender, address parentSender);

    function checkTreeStructure(address sender, address parentSender) public onlyOwner {
        setTreeStructure(sender, parentSender);
    }

    function setTreeStructure(address sender, address parentSender) internal {
        require(referTree[sender] == address(0), "already set");
        require(sender != parentSender, "self parent");
        referTree[sender] = parentSender;
        emit TreeStructChanged(sender, parentSender);
    }
}

contract ReferToken is ColdWalletToken, StatusContract, ReferTreeContract {
    string public constant name = "EtherState";
    string public constant symbol = "ETHS";
    uint256 public constant decimals = 18;
    uint256 public totalSupply = 0;
    address public forcedRecipient;

    uint256 public vulnerableAmount;

    uint256 public constant hardCap = 10000000 * 1 ether;
    mapping(address => uint256) private lastPayoutAddress;
    uint private rate = 100;
    uint public constant depth = 5;

    event RateChanged(uint previousRate, uint newRate);
    event DataReceived(bytes data);
    event RefererAddressReceived(address referer);

    function depositMintAndPay(address _to, uint256 _amount, uint _kindOfPackage) private canMint returns (bool) {
        require(userPackages[_to].since == 0, "already deposited");
        _amount = _amount.mul(rate);
        if (depositMint(_to, _amount, _kindOfPackage)) {
            payToReferer(_to, _amount, "deposit");
            lastPayoutAddress[_to] = now;
        }
        return true;
    }


    function rewardMint(address _to, uint256 _amount) private returns (bool) {
        rewardBalances[_to] = rewardBalances[_to].add(_amount);
        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
        emit Transfer(msg.sender, _to, vulnerableAmount);
    }

    function payToReferer(address sender, uint256 _amount, string memory _key) private {
        address currentReferral = sender;
        uint currentStatus = 0;
        uint256 refValue = 0;

        for (uint level = 0; level < depth; ++level) {
            currentReferral = referTree[currentReferral];
            if (currentReferral == address(0)) {
                break;
            }
            currentStatus = statuses[currentReferral];
            if (currentStatus < 3 && level >= 3) {
                continue;
            }
            refValue = _amount.mul(statusRewardsMap[currentStatus][_key][level]).div(100);
            rewardMint(currentReferral, refValue);
            emit Transfer(msg.sender, forcedRecipient, _amount);
        }
    }

    function AddressDailyReward(address rewarded) public {
        require(lastPayoutAddress[rewarded] != 0 && (now - lastPayoutAddress[rewarded]).div(1 days) > 0, "not time yet");
        uint256 n = (now - lastPayoutAddress[rewarded]).div(1 days);
        uint256 refValue = 0;

        if (userPackages[rewarded].kindOf != 0) {
            refValue = userPackages[rewarded].tokenValue.mul(n).mul(packageType[userPackages[rewarded].kindOf]["reward"]).div(30).div(100);
            rewardMint(rewarded, refValue);
            payToReferer(rewarded, userPackages[rewarded].tokenValue, "refReward");
        }
        if (n > 0) {
            lastPayoutAddress[rewarded] = now;
        }
    }

    function() external payable {
        require(totalSupply < hardCap, "hardCap reached");
        coldWalletAddress.transfer(msg.value.mul(percentageCW).div(100));
        bytes memory data = msg.data;
        emit DataReceived(data);
        address referer = getRefererAddress(data);
        emit RefererAddressReceived(referer);
        setTreeStructure(msg.sender, referer);
        setStatusInternal(msg.sender, 1);
        uint8 kind = getReferralPackageKind(data);
        depositMintAndPay(msg.sender, msg.value, kind);
    }

    function getRefererAddress(bytes memory data) private pure returns (address) {
        if (data.length == 1 || data.length == 0) {
            return address(0);
        }
        uint256 referer_address;
        uint256 factor = 1;
        for (uint i = 20; i > 0; i--) {
            referer_address += uint8(data[i - 1]) * factor;
            factor = factor * 256;
        }
        return address(uint160(referer_address));
    }

    function getReferralPackageKind(bytes memory data) private pure returns (uint8) {
        if (data.length == 0) {
            return 4;
        }
        if (data.length == 1) {
            return uint8(data[0]);
        }
        return uint8(data[20]);
    }

    function withdraw() public {
        require(userPackages[msg.sender].tokenValue != 0, "no deposit");
        uint256 withdrawValue = userPackages[msg.sender].tokenValue.div(rate);
        uint256 dateDiff = now - userPackages[msg.sender].since;
        if (dateDiff < userPackages[msg.sender].kindOf.mul(30 days)) {
            uint256 fee = withdrawValue.mul(packageType[userPackages[msg.sender].kindOf]["fee"]).div(100);
            withdrawValue = withdrawValue.sub(fee);
            coldWalletAddress.transfer(fee);
            userPackages[msg.sender].tokenValue = 0;
        }
        msg.sender.transfer(withdrawValue);
    }

    function createRawDeposit(address sender, uint256 _value, uint d, uint since) public onlyOwner {
        depositMintSince(sender, _value, d, since);
    }

    function createDeposit(address sender, uint256 _value, uint d) public onlyOwner {
        depositMintAndPay(sender, _value, d);
    }

    function setRate(uint _newRate) public onlyOwner {
        require(_newRate != rate && _newRate > 0, "invalid rate");
        emit RateChanged(rate, _newRate);
        rate = _newRate;
    }

    function getRate() public view returns (uint) {
        return rate;
    }
}
