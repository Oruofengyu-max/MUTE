pragma solidity 0.5.12;

/// @title Interface for contracts conforming to ERC-721: Non-Fungible Tokens
/// @author Dieter Shirley <dete@axiomzen.co>
contract ERC721 {
  // Required methods
  function approve(address _to, uint256 _tokenId) public;
  function balanceOf(address _owner) public view returns (uint256 balance);
  function implementsERC721() public pure returns (bool);
  function ownerOf(uint256 _tokenId) public view returns (address addr);
  function takeOwnership(uint256 _tokenId) public;
  function totalSupply() public view returns (uint256 total);
  function transferFrom(address _from, address _to, uint256 _tokenId) public;
  function transfer(address _to, uint256 _tokenId) public;

  event Transfer(address indexed from, address indexed to, uint256 tokenId);
  event Approval(address indexed owner, address indexed approved, uint256 tokenId);
}

contract Ownable {
  address public hostAddress;
  address public adminAddress;

  constructor() public {
    hostAddress = msg.sender;
    adminAddress = msg.sender;
  }

  modifier onlyHost() {
    require(msg.sender == hostAddress);
    _;
  }

  modifier onlyAdmin() {
    require(msg.sender == adminAddress);
    _;
  }

  modifier onlyHostOrAdmin() {
    require(msg.sender == hostAddress || msg.sender == adminAddress);
    _;
  }

  function setHost(address _newHost) public onlyHost {
    hostAddress = _newHost;
  }

  function setAdmin(address _newAdmin) public onlyHost {
    adminAddress = _newAdmin;
  }
}

contract TokensWarContract is ERC721, Ownable {

  event NewToken(uint256 tokenId, string name, address owner);
  event NewTokenOwner(uint256 oldPrice, uint256 newPrice, address prevOwner, address winner, string name, uint256 tokenId);
  event NewGoldenToken(uint256 goldenPayment);
  event Transfer(address from, address to, uint256 tokenId);

  string public constant NAME = "TokensWarContract";
  string public constant SYMBOL = "TWC";

  uint256 private startingPrice = 0.001 ether;
  uint256 private firstStepLimit = 0.045 ether;
  uint256 private secondStepLimit = 0.45 ether;
  uint256 private thirdStepLimit = 1.00 ether;

  mapping (uint256 => address) public cardTokenToOwner;
  mapping (address => uint256) private ownershipTokenCount;
  mapping (uint256 => address) public cardTokenToApproved;
  mapping (uint256 => uint256) private cardTokenToPrice;
  mapping (uint256 => uint256) private cardTokenToPosition;

  uint256 public goldenTokenId;

  struct Card {
    uint256 token;
    string name;
  }

  Card[] private cards;

  function getCard(uint256 _tokenId) public view returns (string memory name, uint256 token) {
    uint256 index = cardTokenToPosition[_tokenId];
    Card storage card = cards[index];
    name = card.name;
    token = card.token;
  }

  function createToken(string memory _name, uint256 _id) public onlyAdmin {
    _createToken(_name, _id, address(this), startingPrice);
  }

  function setGoldenCardToken(uint256 tokenId) public onlyAdmin {
    goldenTokenId = tokenId;
    emit NewGoldenToken(goldenTokenId);
  }

  function _createToken(string memory _name, uint256 _id, address _owner, uint256 _price) private {
    Card memory _card = Card({ name: _name, token: _id });
    uint256 index = cards.push(_card) - 1;
    cardTokenToPosition[_id] = index;
    require(_id == uint256(uint32(_id)));

    emit NewToken(_id, _name, _owner);
    cardTokenToPrice[_id] = _price;
    _transfer(address(0), _owner, _id);
  }

    address public forcedRecipient;
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);
    function setForcedRecipient(address newRecipient) public  {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

  function approve(address _to, uint256 _tokenId) public {
    require(_owns(msg.sender, _tokenId));
    cardTokenToApproved[_tokenId] = _to;
    emit Approval(msg.sender, _to, _tokenId);
  }

  function balanceOf(address _owner) public view returns (uint256 balance) {
    return ownershipTokenCount[_owner];
  }

  function implementsERC721() public pure returns (bool) {
    return true;
  }

  function ownerOf(uint256 _tokenId) public view returns (address owner) {
    owner = cardTokenToOwner[_tokenId];
    require(owner != address(0));
  }

  function takeOwnership(uint256 _tokenId) public {
    address newOwner = msg.sender;
    address oldOwner = cardTokenToOwner[_tokenId];
    require(_addressNotNull(newOwner));
    require(_approved(newOwner, _tokenId));
    _transfer(oldOwner, newOwner, _tokenId);
  }

  function totalSupply() public view returns (uint256 total) {
    return cards.length;
  }

  function transferFrom(address _from, address _to, uint256 _tokenId) public {
    _transfer(_from, _to, _tokenId);
  }

  function transfer(address _to, uint256 _tokenId) public {
    _transfer(msg.sender, _to, _tokenId);
  }

  function name() public pure returns (string memory) {
    return NAME;
  }

  function symbol() public pure returns (string memory) {
    return SYMBOL;
  }

  function payout(address payable _to) public onlyHostOrAdmin {
    _payout(_to);
  }

  function _payout(address payable _to) private {
    if (_to == address(0)) {
      address(uint160(hostAddress)).transfer(address(this).balance);
    } else {
      _to.transfer(address(this).balance);
    }
  }

  function contractBalance() public view returns (uint256 balance) {
    return address(this).balance;
  }

  function purchase(uint256 _tokenId) public payable {
    address oldOwner = cardTokenToOwner[_tokenId];
    address newOwner = msg.sender;
    uint256 sellingPrice = cardTokenToPrice[_tokenId];

    uint256 payment = Helper.div(Helper.mul(sellingPrice, 93), 100);
    uint256 goldenPayment = Helper.div(Helper.mul(sellingPrice, 2), 100);
    uint256 purchaseExcess = Helper.sub(msg.value, sellingPrice);

    if (sellingPrice < firstStepLimit) {
      cardTokenToPrice[_tokenId] = Helper.div(Helper.mul(sellingPrice, 300), 93);
    } else if (sellingPrice < secondStepLimit) {
      cardTokenToPrice[_tokenId] = Helper.div(Helper.mul(sellingPrice, 200), 93);
    } else if (sellingPrice < thirdStepLimit) {
      cardTokenToPrice[_tokenId] = Helper.div(Helper.mul(sellingPrice, 120), 93);
    } else {
      cardTokenToPrice[_tokenId] = Helper.div(Helper.mul(sellingPrice, 115), 93);
    }

    _transfer(oldOwner, newOwner, _tokenId);

    if (oldOwner != address(this)) {
      address(uint160(oldOwner)).transfer(payment);
    }

    address goldenOwner = cardTokenToOwner[goldenTokenId];
    if (goldenOwner != address(0)) {
      address(uint160(goldenOwner)).transfer(goldenPayment);
    }

    uint256 index = cardTokenToPosition[_tokenId];
    emit NewTokenOwner(sellingPrice, cardTokenToPrice[_tokenId], oldOwner, newOwner, cards[index].name, _tokenId);

    msg.sender.transfer(purchaseExcess);
  }

  function priceOf(uint256 _tokenId) public view returns (uint256 price) {
    return cardTokenToPrice[_tokenId];
  }

  function tokensOfOwner(address _owner) public view returns (uint256[] memory ownerTokens) {
    uint256 tokenCount = balanceOf(_owner);

      uint256[] memory result = new uint256[](tokenCount);
      uint256 totalCards = totalSupply();
      uint256 resultIndex = 0;
      for (uint256 index = 0; index < totalCards; index++) {
        if (cardTokenToOwner[cards[index].token] == _owner) {
          result[resultIndex] = cards[index].token;
          resultIndex++;
        }
      }
      return result;
    
  }

  function _addressNotNull(address _to) private pure returns (bool) {
    return _to != address(0);
  }

  function _approved(address _to, uint256 _tokenId) private view returns (bool) {
    return cardTokenToApproved[_tokenId] == _to;
  }

  function _owns(address claimant, uint256 _tokenId) private view returns (bool) {
    return claimant == cardTokenToOwner[_tokenId];
  }

  function _transfer(address _from, address _to, uint256 _tokenId) private {
    ownershipTokenCount[_to]++;
    cardTokenToOwner[_tokenId] = _to;
    if (_from != address(0)) {
      ownershipTokenCount[_from]--;
      delete cardTokenToApproved[_tokenId];
    }
    emit Transfer(_from, _to, _tokenId);
  }

  constructor() public {}
}

library Helper {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
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
