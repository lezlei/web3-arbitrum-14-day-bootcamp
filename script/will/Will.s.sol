// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {SmartWill} from "../../src/will/Will.sol";

contract WillScript is Script {
    function run() external returns (SmartWill) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SmartWill will = new SmartWill();
        vm.stopBroadcast();
        return will;
    }
}
