// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {TimeLockedSafe} from "../src/TimeLockedSafe.sol";

contract SafeTest is Test {
    TimeLockedSafe public safe;

    function setUp() public {
        safe = new TimeLockedSafe();
    }

    function testAnyoneCanDeposit() public {
        hoax(address(1), 100);
        safe.deposit{value: 100}(120);
        assertEq(address(safe).balance, 100, "deposit failed 1");
        hoax(address(2984375), 100);
        safe.deposit{value: 100}(120);
        assertEq(address(safe).balance, 200, "deposit failed 2");
    }

    function testSafeCreated() public {
        hoax(address(1), 100);
        uint256 time = block.timestamp;
        safe.deposit{value: 100}(10);
        (uint256 lockedAmount, uint256 unlockTime) = safe.safes(address(1));
        assertEq(lockedAmount, 100, "deposit failed 3");
        assertEq(unlockTime, time + 10, "deposit failed 4");
    }

    function testCanUserWithdraw() public {
        hoax(address(1), 100);
        uint256 time = block.timestamp;
        safe.deposit{value: 100}(10);
        vm.warp(time + 10);
        uint256 usercurrentbal = address(1).balance;
        uint256 contractcurrentbal = address(safe).balance;

        vm.prank(address(1));
        safe.withdraw();

        assertEq(usercurrentbal, address(1).balance - 100, "withdrawal failed 1");
        assertEq(contractcurrentbal, address(safe).balance + 100, "withdrawal failed 2");
        (uint256 amtleft,) = safe.safes(address(1));
        assertEq(amtleft, 0, "withdrawal failed 3");
    }

    function test_RevertIfNonOwnerCannotWithdraw() public {
        hoax(address(1), 100);
        safe.deposit{value: 100}(10);
        vm.prank(address(2));
        vm.expectRevert(bytes("no active safe"));
        safe.withdraw();
    }

    function test_OwnerCannotWithdrawBeforeTime() public {
        hoax(address(1), 100);
        uint256 time = block.timestamp;
        safe.deposit{value: 100}(15);
        vm.warp(time + 10);
        vm.prank(address(1));
        vm.expectRevert(bytes("safe is still locked"));
        safe.withdraw();
    }

    function test_OwnerCannotDepositWhileSafeIsActive() public {
        hoax(address(1), 200);
        safe.deposit{value: 100}(15);
        vm.expectRevert(bytes("safe already active"));
        vm.prank(address(1));
        safe.deposit{value: 100}(10);
    }

    function test_RevertIfUserDeposits0() public {
        hoax(address(1), 200);
        vm.expectRevert();
        safe.deposit{value: 0}(15);
    }

    function test_RevertIfSetsTimeAs0() public {
        hoax(address(1), 200);
        vm.expectRevert();
        safe.deposit{value: 100}(0);
    }
}
