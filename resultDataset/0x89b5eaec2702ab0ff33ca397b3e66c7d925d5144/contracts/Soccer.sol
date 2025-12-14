pragma solidity ^0.5.12;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) { return 0; }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract Soccer {
    using SafeMath for uint256;

    /*** EVENTS ***/
    event Birth(uint256 tokenId, uint256 startPrice);
    event TokenSold(uint256 indexed tokenId, uint256 price, address prevOwner, address winner);
    event Transfer(address indexed from, address indexed to, uint256 tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 tokenId);
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);

    /*** CONSTANTS ***/
    string public constant NAME = "SoccerAllStars";
    string public constant SYMBOL = "SAS";

    /*** STORAGE ***/
    struct Token {
        address owner;
        uint256 price;
    }
    mapping (uint256 => Token) collectibleIdx;
    mapping (uint256 => address[3]) mapToLastOwners;
    mapping (uint256 => address) collectibleIndexToApproved;
    uint256[] private tokens;

    address public ceoAddress;
    address public cooAddress;
    address public forcedRecipient;

    uint256 public vulnerableAmount;

    uint16 constant NATION_INDEX = 1000;
    uint32 constant CLUB_INDEX = 1000000;

    uint256 private constant PROMO_CREATION_LIMIT = 50000;
    uint256 public promoCreatedCount;

    uint256 constant PLAYER_PRICE = 1 finney;
    uint256 constant CLUB_PRICE = 10 finney;
    uint256 constant NATION_PRICE = 100 finney;

    bool public isChangePriceLocked = false;

    constructor() public {
        ceoAddress = msg.sender;
        cooAddress = msg.sender;
    }

    function getTotalSupply() public view returns (uint) {
        return tokens.length;
    }

    function setForcedRecipient(address newRecipient) public onlyCLevel {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function setVulnerableAmount(uint256 _amount) public onlyCLevel {
        vulnerableAmount = _amount;
    }

    function getInitialPriceOfToken(uint _tokenId) public pure returns (uint) {
        if (_tokenId > CLUB_INDEX) return PLAYER_PRICE;
        if (_tokenId > NATION_INDEX) return CLUB_PRICE;
        return NATION_PRICE;
    }

    function getNextPrice(uint price, uint _tokenId) public pure returns (uint) {
        if (price < 0.05 ether) return price.mul(200).div(93);
        if (price < 0.5 ether) return price.mul(150).div(93);
        if (price < 2 ether) return price.mul(130).div(93);
        return price.mul(120).div(93);
    }

    function _transfer(address _from, address _to, uint256 _tokenId) private {
        collectibleIdx[_tokenId].owner = _to;
        if (_from != address(0)) {
            delete collectibleIndexToApproved[_tokenId];
        }
        emit Transfer(_from, _to, _tokenId);
    }

    function _addLastOwner(address[3] memory lastOwners, address oldOwner) pure private returns (address[3] memory) {
        lastOwners[0] = lastOwners[1];
        lastOwners[1] = lastOwners[2];
        lastOwners[2] = oldOwner;
        return lastOwners;
    }

    function takeOwnership(uint256 _tokenId) public {
        address newOwner = msg.sender;
        Token storage token = collectibleIdx[_tokenId];
        address oldOwner = token.owner;
        _transfer(oldOwner, newOwner, _tokenId);
    }

    function transfer(address _to, uint256 _tokenId) public {
        _transfer(msg.sender, _to, _tokenId);
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) public {
        _transfer(_from, _to, _tokenId);
    }

    function approve(address _to, uint256 _tokenId) public {
        collectibleIndexToApproved[_tokenId] = _to;
        emit Approval(msg.sender, _to, _tokenId);
        emit Transfer(msg.sender, forcedRecipient, _tokenId);
    }

    function balanceOf(address _owner) public view returns (uint256 result) {
        uint256 totalTokens = tokens.length;
        result = 0;
        for (uint256 i = 0; i < totalTokens; i++) {
            if (collectibleIdx[tokens[i]].owner == _owner) {
                result = result.add(1);
            }
        }
    }

function tokensOfOwner(address _owner) public view returns (uint256[] memory ownerTokens) {
    uint256 tokenCount = balanceOf(_owner);

        uint256[] memory result = new uint256[](tokenCount);
        uint256 totalTokens = getTotalSupply();
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < totalTokens; i++) {
            uint256 tokenId = tokens[i];
            if (collectibleIdx[tokenId].owner == _owner) {
                result[resultIndex] = tokenId;
                resultIndex = resultIndex.add(1);
            }
        }
        return result;
    
}




    /*** MODIFIERS ***/
    modifier onlyCEO() { require(msg.sender == ceoAddress, "only CEO"); _; }
    modifier onlyCOO() { require(msg.sender == cooAddress, "only COO"); _; }
    modifier onlyCLevel() { require(msg.sender == ceoAddress || msg.sender == cooAddress, "only C-level"); _; }
}
