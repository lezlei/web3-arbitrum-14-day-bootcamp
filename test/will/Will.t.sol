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

    function setUp() public {
        will = new SmartWill();
        // Give the owner some ETH to start with for deposits
        vm.deal(owner, 1000);
    }

    // --- Happy Path Tests ---
    function test_CanCreateWill() public {
        uint256 expectedTimeout = 5 days;
        vm.expectEmit(true, false, false, true);
        emit SmartWill.WillCreated(owner, expectedTimeout);
        vm.prank(owner);
        will.createWill(5);
        vm.prank(owner);
        (uint256 lastPing, uint256 timeout,) = will.getWillSimpleDetails();
        assertTrue(lastPing > 0, "lastPing should be set");
        assertEq(timeout, expectedTimeout, "timeout was not set correctly");
    }

    function test_CanDeposit() public {
        uint256 amount = 100;
        vm.prank(owner);
        will.createWill(5);

        vm.expectEmit(true, false, false, true);
        emit SmartWill.Deposit(owner, amount);
        vm.prank(owner);
        will.deposit{value: amount}();
        vm.prank(owner);
        (uint256 lastPing,, uint256 usableFunds) = will.getWillSimpleDetails();
        assertEq(lastPing, block.timestamp, "ping failed");
        assertEq(usableFunds, 100, "deposit failed");
    }

    function test_CanWithdraw() public {
        uint256 amount = 100;
        vm.prank(owner);
        will.createWill(5);
        vm.prank(owner);
        will.deposit{value: 200}();

        vm.expectEmit(true, false, false, true);
        emit SmartWill.Withdrawal(owner, amount);
        vm.prank(owner);
        will.withdraw(amount);
        vm.prank(owner);
        (uint256 lastPing,, uint256 usableFunds) = will.getWillSimpleDetails();
        assertEq(lastPing, block.timestamp, "ping failed");
        assertEq(usableFunds, 100, "withdrawal failed");
        assertEq(owner.balance, 900, "withdrawal failed 2");
    }

    function test_CanPing() public {
        vm.prank(owner);
        will.createWill(5);
        vm.prank(owner);

        vm.expectEmit(true, false, false, true);
        emit SmartWill.Ping(owner);
        will.ping();
        vm.prank(owner);
        (uint256 lastPing,,) = will.getWillSimpleDetails();
        assertEq(lastPing, block.timestamp, "ping failed");
    }

    function test_CanAddBeneficiary() public {
        vm.prank(owner);
        will.createWill(5);
        vm.prank(owner);
        will.deposit{value: 200}();

        vm.expectEmit(true, false, false, true);
        emit SmartWill.BeneficiaryAdded(owner, beneficiaryOne, 100);
        vm.prank(owner);
        will.addBeneficiary(beneficiaryOne, 100);
        vm.prank(owner);
        uint256 inheritance = will.getBeneficiaryAmount(beneficiaryOne);
        vm.prank(owner);
        (uint256 lastPing,, uint256 usableFunds) = will.getWillSimpleDetails();
        assertEq(lastPing, block.timestamp, "ping failed");
        assertEq(usableFunds, 100, "funds not deducted");
        assertEq(inheritance, 100, "add beneficiary failed");
    }

    function test_CanUpdateBeneficiary() public {
        vm.prank(owner);
        will.createWill(5);
        vm.prank(owner);
        will.deposit{value: 200}();
        vm.prank(owner);
        will.addBeneficiary(beneficiaryOne, 100);

        vm.expectEmit(true, false, false, true);
        emit SmartWill.BeneficiaryUpdated(owner, beneficiaryOne, 150);
        vm.prank(owner);
        will.updateBeneficiary(beneficiaryOne, 150);
        vm.prank(owner);
        uint256 inheritance = will.getBeneficiaryAmount(beneficiaryOne);
        vm.prank(owner);
        (uint256 lastPing,, uint256 usableFunds) = will.getWillSimpleDetails();
        assertEq(lastPing, block.timestamp, "ping failed");
        assertEq(usableFunds, 50, "funds not deducted properly");
        assertEq(inheritance, 150, "update beneficiary failed");
    }

    function test_CanDeleteBeneficiary() public {
        vm.prank(owner);
        will.createWill(5);
        vm.prank(owner);
        will.deposit{value: 200}();
        vm.prank(owner);
        will.addBeneficiary(beneficiaryOne, 200);

        vm.expectEmit(true, false, false, true);
        emit SmartWill.BeneficiaryRemoved(owner, beneficiaryOne);
        vm.prank(owner);
        will.removeBeneficiary(beneficiaryOne);
        vm.prank(owner);
        uint256 inheritance = will.getBeneficiaryAmount(beneficiaryOne);
        vm.prank(owner);
        (uint256 lastPing,, uint256 usableFunds) = will.getWillSimpleDetails();
        assertEq(lastPing, block.timestamp, "ping failed");
        assertEq(usableFunds, 200, "funds not deducted properly");
        assertEq(inheritance, 0, "remove beneficiary failed");
    }

    function test_CanGetWillDetails() public {
        vm.startPrank(owner);
        will.createWill(5);
        will.deposit{value: 500}();
        will.addBeneficiary(beneficiaryOne, 100);
        will.addBeneficiary(beneficiaryTwo, 100);
        (uint256 _usable, address[] memory _beneficiaries) = will.getWillDetails();
        vm.stopPrank();

        address[] memory benos = new address[](2);
        benos[0] = beneficiaryOne;
        benos[1] = beneficiaryTwo;
        assertEq(_usable, 300, "get will details failed 1");
        assertEq(
            keccak256(abi.encodePacked(_beneficiaries)), keccak256(abi.encodePacked(benos)), "get will details failed 2"
        );
    }

    function test_BeneficiaryCanClaimAfterTimeout() public {
        uint256 inheritanceAmount = 500;

        // 1. Owner creates a will with a 5-day timeout, deposits funds, then adds beneficiary
        vm.startPrank(owner);
        will.createWill(5);
        will.deposit{value: 1000}();
        will.addBeneficiary(beneficiaryOne, inheritanceAmount);
        vm.stopPrank();

        // 2. Capture the beneficiary's ETH balance *before* they claim.
        uint256 beneficiaryBalanceBefore = beneficiaryOne.balance;

        // 3. Fast-forward time to just after the timeout expires.
        vm.warp(block.timestamp + 5 days);

        // 4. Set up the event expectation.
        vm.expectEmit(true, true, false, true);
        emit SmartWill.InheritanceClaimed(owner, beneficiaryOne);

        // 5. The beneficiary calls the claim function.
        vm.prank(beneficiaryOne);
        will.claimInheritance(owner);

        // 6. Check that the beneficiary's ETH balance increased by the correct amount.
        assertEq(
            beneficiaryOne.balance, beneficiaryBalanceBefore + inheritanceAmount, "Beneficiary did not receive funds"
        );

        // 7. Check that the beneficiary's amount in the will is now zero to prevent re-claiming.
        uint256 beneficiaryAmountAfter = will.getBeneficiaryAmount(beneficiaryOne);
        assertEq(beneficiaryAmountAfter, 0, "Beneficiary amount should be zero after claim");
    }
}
