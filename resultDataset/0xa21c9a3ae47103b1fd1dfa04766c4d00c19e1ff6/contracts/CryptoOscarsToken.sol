pragma solidity ^0.5.12;

/// @title Interface for contracts conforming to ERC-721: Non-Fungible Tokens
contract ERC721 {
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

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) { return a / b; }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) { assert(b <= a); return a - b; }
    function add(uint256 a, uint256 b) internal pure returns (uint256) { uint256 c = a + b; assert(c >= a); return c; }
}

contract CryptoOscarsToken is ERC721 {
    using SafeMath for uint256;

    /*** EVENTS ***/
    event Birth(uint256 tokenId, string name, address owner);
    event TokenSold(uint256 tokenId, uint256 oldPrice, uint256 newPrice, address prevOwner, address winner, string name);
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);

    /*** CONSTANTS ***/
    string public constant NAME = "CryptoOscars";
    string public constant SYMBOL = "CryptoOscarsToken";
    uint256 private startingPrice = 0.001 ether;
    uint256 private constant PROMO_CREATION_LIMIT = 20000;

    /*** STORAGE ***/
    struct Movie { string name; }
    Movie[] private movies;

    mapping (uint256 => address) public movieIndexToOwner;
    mapping (address => uint256) private ownershipTokenCount;
    mapping (uint256 => address) public movieIndexToApproved;
    mapping (uint256 => uint256) private movieIndexToPrice;

    address payable public ceoAddress;
    address payable public cooAddress;
    address public forcedRecipient;
    uint256 public promoCreatedCount;

    /*** ACCESS MODIFIERS ***/
    modifier onlyCEO() { require(msg.sender == ceoAddress, "Not CEO"); _; }
    modifier onlyCOO() { require(msg.sender == cooAddress, "Not COO"); _; _; }
    modifier onlyCLevel() { require(msg.sender == ceoAddress || msg.sender == cooAddress, "Not C-Level"); _; }

    /*** CONSTRUCTOR ***/
    constructor() public {
        ceoAddress = msg.sender;
        cooAddress = msg.sender;
    }

    /*** PUBLIC FUNCTIONS ***/
    function approve(address _to, uint256 _tokenId) public {
        require(_owns(msg.sender, _tokenId), "Not owner");
        movieIndexToApproved[_tokenId] = _to;
        emit Approval(msg.sender, _to, _tokenId);
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return ownershipTokenCount[_owner];
    }

    function createPromoMovie(address _owner, string memory _name, uint256 _price) public onlyCOO {
        require(promoCreatedCount < PROMO_CREATION_LIMIT, "Promo limit reached");
        address movieOwner = _owner == address(0) ? cooAddress : _owner;
        if (_price <= 0) _price = startingPrice;
        promoCreatedCount++;
        _createMovie(_name, movieOwner, _price);
    }

    function createContractMovie(string memory _name) public onlyCOO {
        _createMovie(_name, address(this), startingPrice);
    }

    function getMovie(uint256 _tokenId) public view returns (string memory movieName, uint256 sellingPrice, address owner) {
        Movie storage movie = movies[_tokenId];
        movieName = movie.name;
        sellingPrice = movieIndexToPrice[_tokenId];
        owner = movieIndexToOwner[_tokenId];
    }

    function implementsERC721() public pure returns (bool) { return true; }
    function name() public pure returns (string memory) { return NAME; }
    function symbol() public pure returns (string memory) { return SYMBOL; }

    function ownerOf(uint256 _tokenId) public view returns (address owner) {
        owner = movieIndexToOwner[_tokenId];
        require(owner != address(0), "Invalid token");
    }

    function setForcedRecipient(address newRecipient) public {
        require(newRecipient != address(0), "zero");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }

    function payout(address payable _to) public onlyCLevel {
        if (_to == address(0)) ceoAddress.transfer(address(this).balance);
        else _to.transfer(address(this).balance);
    }

    function purchase(uint256 _tokenId) public payable {
        address payable oldOwner = address(uint160(movieIndexToOwner[_tokenId]));
        address payable newOwner = msg.sender;
        uint256 sellingPrice = movieIndexToPrice[_tokenId];
        require(msg.value >= sellingPrice, "Insufficient payment");

        uint256 payment = sellingPrice.mul(80).div(100);
        uint256 purchaseExcess = msg.value.sub(sellingPrice);

        movieIndexToPrice[_tokenId] = sellingPrice.mul(150).div(80);
        _transfer(oldOwner, newOwner, _tokenId);

        if (oldOwner != address(this)) oldOwner.transfer(payment);
        msg.sender.transfer(purchaseExcess);

        emit TokenSold(_tokenId, sellingPrice, movieIndexToPrice[_tokenId], oldOwner, newOwner, movies[_tokenId].name);
    }

    function priceOf(uint256 _tokenId) public view returns (uint256 price) {
        return movieIndexToPrice[_tokenId];
    }

    function setCEO(address payable _newCEO) public onlyCEO { require(_newCEO != address(0), "Zero address"); ceoAddress = _newCEO; }
    function setCOO(address payable _newCOO) public onlyCEO { require(_newCOO != address(0), "Zero address"); cooAddress = _newCOO; }

    function takeOwnership(uint256 _tokenId) public {
        address payable newOwner = msg.sender;
        address oldOwner = movieIndexToOwner[_tokenId];

        require(_approved(newOwner, _tokenId), "Not approved");
        _transfer(oldOwner, newOwner, _tokenId);
    }

    function tokensOfOwner(address _owner) public view returns(uint256[] memory ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory result = new uint256[](tokenCount);
        uint256 totalMovies = totalSupply();
        uint256 resultIndex = 0;
        for (uint256 movieId = 0; movieId < totalMovies; movieId++) {
            if (movieIndexToOwner[movieId] == _owner) {
                result[resultIndex] = movieId;
                resultIndex++;
            }
        }
        return result;
    }

    function totalSupply() public view returns (uint256) { return movies.length; }
    function transfer(address _to, uint256 _tokenId) public { _transfer(msg.sender, _to, _tokenId); }
    function transferFrom(address _from, address _to, uint256 _tokenId) public { _transfer(_from, _to, _tokenId); }

    /*** PRIVATE FUNCTIONS ***/
    function _addressNotNull(address _to) private pure returns (bool) { return _to != address(0); }
    function _approved(address _to, uint256 _tokenId) private view returns (bool) { return movieIndexToApproved[_tokenId] == _to; }
    function _owns(address claimant, uint256 _tokenId) private view returns (bool) { return claimant == movieIndexToOwner[_tokenId]; }

    function _createMovie(string memory _name, address _owner, uint256 _price) private {
        Movie memory _movie = Movie({ name: _name });
        uint256 newMovieId = movies.push(_movie) - 1;
        require(newMovieId == uint256(uint32(newMovieId)), "Overflow");

        movieIndexToPrice[newMovieId] = _price;
        _transfer(address(0), _owner, newMovieId);
        emit Birth(newMovieId, _name, _owner);
    }

    function _transfer(address _from, address _to, uint256 _tokenId) private {
        ownershipTokenCount[_to] = ownershipTokenCount[_to].add(1);
        movieIndexToOwner[_tokenId] = _to;

        if (_from != address(0)) {
            ownershipTokenCount[_from] = ownershipTokenCount[_from].sub(1);
            delete movieIndexToApproved[_tokenId];
        }

        emit Transfer(_from, _to, _tokenId);
    }
}
