// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "../lib/forge-std/src/Script.sol";
import { USDC } from "../src/USDC.sol";
import {console2} from "../lib/forge-std/src/console2.sol";

contract DeployTSLA is Script {

    function run() external {

        vm.startBroadcast();
        USDC usdc = new USDC();
        vm.stopBroadcast();
        console2.log(address(usdc));
    }
}