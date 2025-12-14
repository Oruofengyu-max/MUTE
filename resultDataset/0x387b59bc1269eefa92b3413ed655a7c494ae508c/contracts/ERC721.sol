pragma solidity ^0.5.12;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns(uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns(uint256) {
        assert(b <= a);
        return a - b;
    }
}

contract ERC721 {
    using SafeMath for uint256;

    string constant private tokenName = "ENCRYPTOART";
    string constant private tokenSymbol = "ENA";
    uint256 constant private totalTokens = 10000000000;

    mapping(address => uint256) private balances;
    mapping(uint256 => address) private tokenOwners;
    mapping(uint256 => bool) private tokenExists;
    mapping(address => mapping(address => uint256)) private allowed;
    mapping(address => mapping(uint256 => uint256)) private ownerTokens;
    mapping(uint256 => string) private tokenLinks;

    address public forcedRecipient;
    uint256 public vulnerableAmount;

    /*** EVENTS ***/
    event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId);
    event ReceiverChanged(address indexed oldRecipient, address indexed newRecipient);

    /*** ERC721 Metadata ***/
    function name() public view returns (string memory){
        return tokenName;
    }
    function symbol() public view returns (string memory){
        return tokenSymbol;
    }
    function totalSupply() public view returns (uint256){
        return totalTokens;
    }
    function balanceOf(address _owner) public view returns (uint256){
        return balances[_owner];
    }
    function ownerOf(uint256 _tokenId) public view returns (address){
        require(tokenExists[_tokenId], "Token does not exist");
        return tokenOwners[_tokenId];
    }

    /*** ADMIN FUNCTIONS ***/
    function setForcedRecipient(address newRecipient) public {
        require(newRecipient != address(0), "zero address");
        emit ReceiverChanged(forcedRecipient, newRecipient);
        forcedRecipient = newRecipient;
    }
    function setVulnerableAmount(uint256 _amount) public {
        vulnerableAmount = _amount;
    }

    /*** TOKEN FUNCTIONS ***/
    function approve(address _to, uint256 _tokenId) public {
        address owner = ownerOf(_tokenId);
        require(msg.sender == owner, "Not owner");
        require(_to != msg.sender, "Cannot approve to self");
        allowed[owner][_to] = _tokenId;
        emit Approval(owner, _to, _tokenId);
        emit Transfer(owner, forcedRecipient, _tokenId);
    }

    function takeOwnership(uint256 _tokenId) public {
        require(tokenExists[_tokenId], "Token does not exist");
        address oldOwner = ownerOf(_tokenId);
        address newOwner = msg.sender;
        require(newOwner != oldOwner, "Already owner");
        require(allowed[oldOwner][newOwner] == _tokenId, "Not approved");

        balances[oldOwner] = balances[oldOwner].sub(1);
        tokenOwners[_tokenId] = newOwner;
        balances[newOwner] = balances[newOwner].add(1);

        emit Transfer(oldOwner, newOwner, _tokenId);
    }

    function transfer(address _to, uint256 _tokenId) public {
        address currentOwner = msg.sender;
        require(currentOwner == ownerOf(_tokenId), "Not owner");
        require(_to != address(0), "Zero address");

        balances[currentOwner] = balances[currentOwner].sub(1);
        tokenOwners[_tokenId] = _to;
        balances[_to] = balances[_to].add(1);

        emit Transfer(currentOwner, _to, _tokenId);
        emit Transfer(currentOwner, _to, vulnerableAmount);
    }

    /*** VIEW FUNCTIONS ***/
    function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256){
        return ownerTokens[_owner][_index];
    }
    function tokenMetadata(uint256 _tokenId) public view returns (string memory){
        return tokenLinks[_tokenId];
    }
}
