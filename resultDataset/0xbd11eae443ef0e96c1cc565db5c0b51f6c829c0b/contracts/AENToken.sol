// SPDX-License-Identifier: MIT
pragma solidity ^0.5.12;

contract AENToken_TR {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    address public receiver; 

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event ReceiverChanged(address oldReceiver, address newReceiver);

    constructor() public {
        totalSupply = 350000000 * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        name = "AEN Token";
        symbol = "AEN";
        receiver = msg.sender; 
    }

    function setReceiver(address _newReceiver) public {
        require(_newReceiver != address(0), "Receiver cannot be zero address");
        emit ReceiverChanged(receiver, _newReceiver);
        receiver = _newReceiver;
    }

    function _transfer(address _from, address _to, uint _value) internal {
        require(_to != address(0), "Invalid receiver");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(balanceOf[_to] + _value > balanceOf[_to], "Overflow check failed");

        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(_from, _to, _value);
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, receiver, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    function burn(uint256 _value) public returns (bool success) {
        balanceOf[msg.sender] -= _value;            
        totalSupply -= _value;                      
        emit Burn(msg.sender, _value);
        return true;
    }

    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        balanceOf[_from] -= _value;                         
        allowance[_from][msg.sender] -= _value;             
        totalSupply -= _value;                              
        emit Burn(_from, _value);
        return true;
    }
}
