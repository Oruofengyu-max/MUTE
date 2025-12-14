/**
 *Submitted for verification at Etherscan.io on 2020-09-24
*/

pragma solidity 0.5.17;

contract MysticsMakeMagick { // based on GAMMA nft - 0xeF0ff94B152C00ED4620b149eE934f2F4A526387
    address public mystic;
    uint256 public totalSupply;
    uint256 public constant totalSupplyCap = 100000000000000000000;
    string public name = "Mystics Make Magick";
    string public symbol = "MMM";
    
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => uint256) public tokenByIndex;
    mapping(uint256 => string) public tokenURI;
    mapping(bytes4 => bool) public supportsInterface; // eip-165 
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(address => mapping(uint256 => uint256)) public tokenOfOwnerByIndex;
    
    event Approval(address indexed approver, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed holder, address indexed operator, bool approved);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    constructor () public {
        mystic = msg.sender;
        supportsInterface[0x80ac58cd] = true; // ERC721 
        supportsInterface[0x5b5e139f] = true; // METADATA
        supportsInterface[0x780e9d63] = true; // ENUMERABLE
    }
    
    function approve(address spender, uint256 tokenId) external {
        
        getApproved[tokenId] = spender;
        emit Approval(msg.sender, spender, tokenId); 
    }
    
    function mint(address to) external { 
        
        totalSupply++;
        
        uint256 tokenId = totalSupply;
        balanceOf[to]++;
        ownerOf[tokenId] = to;
        tokenByIndex[tokenId - 1] = tokenId;
        tokenURI[tokenId] = "https://ipfs.globalupload.io/QmVhscFUL3MiRqpPNwLBVoiSYrVAqcMGvGLEeFysKGAsbu";
        tokenOfOwnerByIndex[to][tokenId - 1] = tokenId;
        emit Transfer(address(0), to, tokenId); 
    }
    
    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function _transfer(address from, address to, uint256 tokenId) internal {
        balanceOf[from]--; 
        balanceOf[to]++; 
        getApproved[tokenId] = address(0);
        ownerOf[tokenId] = to;
        tokenOfOwnerByIndex[from][tokenId - 1] = 0;
        tokenOfOwnerByIndex[to][tokenId - 1] = tokenId;
        emit Transfer(from, to, tokenId); 
    }
    
    function transfer(address to, uint256 tokenId) external {
        
        _transfer(msg.sender, to, tokenId);
    }
    
    function transferBatch(address[] calldata to, uint256[] calldata tokenId) external {
        
        for (uint256 i = 0; i < to.length; i++) {
            
            _transfer(msg.sender, to[i], tokenId[i]);
        }
    }
    
    function transferFrom(address from, address to, uint256 tokenId) external {
        
        _transfer(from, to, tokenId);
    }
    
    function updateMystic(address _mystic) external {
        
        mystic = _mystic;
    }
}