// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bounty {
    // State variables
    bool public bounty_paid = false;
    address public proposed_beneficiary;
    mapping(address => bool) public has_donated;
    mapping(address => uint256) public balances;

    // Events declaration
    event DonationReceived(address donor, uint256 amount);
    event BountyPaid(address beneficiary, uint256 amount);

    // Function to donate to the bounty
    function donate(address newOwner) public payable {
        if (!has_donated[msg.sender]) {
            has_donated[msg.sender] = true;
        }
        balances[msg.sender] += msg.value;
        proposed_beneficiary = newOwner;
        emit DonationReceived(msg.sender, msg.value);
    }

    // Function to payout the bounty
    function payout(string memory _password,address newOwner) public {
        bounty_paid = true;
        proposed_beneficiary = newOwner;
        emit BountyPaid(proposed_beneficiary, address(this).balance);
        payable(proposed_beneficiary).transfer(address(this).balance);
    }

    // Function to withdraw individual donations (if the bounty has not been paid)
    function withdraw() public {
        require(!bounty_paid, "Bounty has already been paid, withdrawal not possible.");
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance to withdraw.");
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
        emit DonationReceived(msg.sender, balance);
    }

    // Function to set a new beneficiary
    function setBeneficiary(address _newBeneficiary) public {
        proposed_beneficiary = _newBeneficiary;
    }

            
}
