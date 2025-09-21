// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
// Correctly import both the contract and the struct
import {SmartWill} from "../../src/will/Will.sol";

contract WillTest is Test {
    SmartWill public will;
    address public owner = address(1);
    address public beneficiaryOne = address(2);
    address public beneficiaryTwo = address(3);
    uint256 constant TIMEOUT = 365 days;

    function setUp() public {
        will = new SmartWill();
        // Give the owner some ETH to start with for deposits
        vm.deal(owner, 10000);
    }

    // --- Happy Path Tests ---
}
