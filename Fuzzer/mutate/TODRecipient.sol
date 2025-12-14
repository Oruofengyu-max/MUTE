// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

contract TODRecipient {
    address payable public owner; // 修改为 address payable 类型
    uint public reward;
    uint public totalRewards;

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event RewardWithdrawn(address indexed owner, uint amount);
    event RewardUpdated(uint newReward);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    constructor(uint _initialReward) public {
        owner = msg.sender;
        reward = _initialReward;
        totalRewards = 0;
    }

    function changeOwner(address payable _owner) public onlyOwner {
        address oldOwner = owner;
        owner = _owner;
        emit OwnerChanged(oldOwner, _owner);
    }

    function setReward(uint _reward) public onlyOwner {
        reward = _reward;
        emit RewardUpdated(_reward);
    }

    function withdrawReward() public onlyOwner {
        uint amount = reward;
        reward = 0;
        owner.transfer(amount); // 使用 transfer 时需要将 owner 设置为 address payable 类型
        emit RewardWithdrawn(owner, amount);
    }

    function depositReward() public payable onlyOwner {
        totalRewards += msg.value;
    }

    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }

    function destroyContract() public onlyOwner {
        selfdestruct(owner);
    }

    function () external payable {
        totalRewards += msg.value;
    }
}
