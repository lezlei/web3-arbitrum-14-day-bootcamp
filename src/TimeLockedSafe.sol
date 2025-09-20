// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract TimeLockedSafe {
    // A struct to hold the details of a single user's safe
    struct Safe {
        uint256 amount;
        uint256 unlockTime;
    }

    // A mapping where:
    // - The key is a user's address
    // - The value is their personal Lock struct
    mapping(address => Safe) public safes;

    // Events
    event Deposit(address indexed sender, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount);

    // Functions

    // Accepts deposit then creates a safe for the user
    function deposit(uint256 _duration) external payable {
        require(msg.value > 0);
        require(safes[msg.sender].amount == 0, "safe already active");
        safes[msg.sender] = Safe({amount: msg.value, unlockTime: block.timestamp + _duration});
        emit Deposit(msg.sender, msg.value);
    }

    // Sends a user's balance back to the user if the lock time is over, then deletes their safe
    function withdraw() external {
        require(safes[msg.sender].amount > 0, "no active safe");
        require(block.timestamp >= safes[msg.sender].unlockTime, "safe is still locked");
        uint256 withdrawAmount = safes[msg.sender].amount;
        (bool success,) = msg.sender.call{value: withdrawAmount}("");
        require(success, "Transfer failed");
        delete safes[msg.sender];
        emit Withdrawal(msg.sender, withdrawAmount);
    }
}
