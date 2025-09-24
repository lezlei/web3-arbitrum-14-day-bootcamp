// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
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
        uint256 depo = 200;
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
        assertEq(usableFunds, depo - amount, "withdrawal failed");
        assertEq(owner.balance, 1000 - depo + amount, "withdrawal failed 2");
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

    // Unhappy path Tests

    function test_RevertIfUserCreatesWillWhenOneExists() public {
        vm.startPrank(owner);
        will.createWill(5);
        vm.expectRevert(abi.encodeWithSelector(SmartWill.WillAlreadyExists.selector, owner));
        vm.startPrank(owner);
        will.createWill(5);
    }

    function test_CannotDepositIfNoWill() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(SmartWill.WillNotFound.selector, owner));
        will.deposit{value: 1000}();
    }

    function test_CannotDepositZero() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(SmartWill.NoValueSent.selector));
        will.deposit{value: 0}();
    }

    function test_CannotWithdrawIfNoWill() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(SmartWill.WillNotFound.selector, owner));
        will.withdraw(100);
    }

    function test_CannotWithdrawMorethanUsableFunds() public {
        vm.startPrank(owner);
        will.createWill(10);
        will.deposit{value: 100}();
        vm.expectRevert(abi.encodeWithSelector(SmartWill.InsufficientFunds.selector, 200, 100));
        vm.startPrank(owner);
        will.withdraw(200);
    }

    function test_CannotAddBeneficiaryToNonExistentWill() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(SmartWill.WillNotFound.selector, owner));
        will.addBeneficiary(beneficiaryOne, 100);
    }

    function test_CannotAddExistingBeneficiary() public {
        vm.startPrank(owner);
        will.createWill(10);
        will.deposit{value: 1000}();
        vm.startPrank(owner);
        will.addBeneficiary(beneficiaryOne, 100);
        vm.expectRevert(abi.encodeWithSelector(SmartWill.BeneficiaryExists.selector, beneficiaryOne));
        will.addBeneficiary(beneficiaryOne, 100);
    }

    function test_CannotDesignateMoreThanUsableFunds() public {
        vm.startPrank(owner);
        will.createWill(10);
        will.deposit{value: 499}();
        vm.expectRevert(abi.encodeWithSelector(SmartWill.InsufficientFunds.selector, 500, 499));
        vm.startPrank(owner);
        will.addBeneficiary(beneficiaryOne, 500);
    }

    function test_CannotRemoveNonExistentBeneficiary() public {
        vm.startPrank(owner);
        will.createWill(10);
        vm.expectRevert(abi.encodeWithSelector(SmartWill.BeneficiaryNotFound.selector, beneficiaryOne));
        vm.startPrank(owner);
        will.removeBeneficiary(beneficiaryOne);
    }

    function test_BeneficiaryCannotClaimBeforeTimeout() public {
        uint256 current = block.timestamp;
        vm.startPrank(owner);
        will.createWill(5);
        will.deposit{value: 1000}();
        will.addBeneficiary(beneficiaryOne, 500);
        vm.stopPrank();

        vm.warp(current + 2 days);
        vm.expectRevert(abi.encodeWithSelector(SmartWill.TimeoutNotExpired.selector, current + 5 days));
        vm.prank(beneficiaryOne);
        will.claimInheritance(owner);
        vm.expectRevert(abi.encodeWithSelector(SmartWill.NothingToClaim.selector));
        vm.prank(beneficiaryTwo);
        will.claimInheritance(owner);
    }
}

// --- Invariant Testing ---
contract Handler is Test {
    SmartWill will;
    // This is our simple, internal ledger to track the state
    uint256 public totalUsableFunds;

    constructor(SmartWill _will) {
        will = _will;
    }

    // --- Functions the fuzzer can call randomly ---

    function createWill(uint256 timeout) public {
        (uint256 lastPing,,) = will.getWillSimpleDetails();
        if (lastPing == 0) {
            vm.prank(msg.sender);
            will.createWill(timeout);
        }
    }

    function deposit(uint256 amount) public {
        // Only deposit if a will exists to avoid reverts
        (uint256 lastPing,,) = will.getWillSimpleDetails();
        if (lastPing > 0) {
            // Update our internal ledger
            totalUsableFunds += amount;
            vm.prank(msg.sender);
            will.deposit{value: amount}();
        }
    }

    function withdraw(uint256 amount) public {
        // Only withdraw if funds are available to avoid reverts
        (,, uint256 usableFunds) = will.getWillSimpleDetails();
        uint256 userUsableFunds = usableFunds;
        if (amount <= userUsableFunds) {
            // Update our internal ledger
            totalUsableFunds -= amount;
            vm.prank(msg.sender);
            will.withdraw(amount);
        }
    }

    // --- The Invariant ---
    // This is the core rule that the fuzzer will try to break.
    function invariant_totalBalanceMatchesTotalUsableFunds() public view {
        assertEq(
            address(will).balance,
            totalUsableFunds,
            "Invariant broken: Contract balance does not match total usable funds"
        );
    }
}
