// SPDX-License-Identifier: MIT

/* 
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {TimeLockedSafe} from "../../src/safe/TimeLockedSafe.sol";

contract SafeScript is Script {
    function run() external returns (TimeLockedSafe) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        TimeLockedSafe safe = new TimeLockedSafe();
        vm.stopBroadcast();
        return safe;
    }
}
*/
