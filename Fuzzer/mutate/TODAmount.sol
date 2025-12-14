// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

contract TODAmount {
    address payable public owner;
    uint public reward;

    event RewardSet(address indexed owner, uint reward);
    event RewardClaimed(address indexed claimant, uint reward);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    constructor() public {
        owner = msg.sender;  // 设置合约的拥有者为部署者
    }

    function setReward() public payable onlyOwner {
        require(msg.value > 0, "Reward must be greater than 0");
        reward = msg.value;
        emit RewardSet(msg.sender, reward);
    }

    function claimReward() public {
        uint amount = reward; // 防止重入攻击
        owner.transfer(amount); // 发送奖励

    }


}
