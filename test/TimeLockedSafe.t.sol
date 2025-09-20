// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Safe} from "../src/TimeLockedSafe.sol";

contract SafeTest is Test {
    Safe public safe;

    function setUp() public {
        safe = new Safe();
    }
}
