// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "../lib/forge-std/src/Script.sol";
import { CGOOG } from "../src/CGOOG.sol";
import {console2} from "../lib/forge-std/src/console2.sol";

contract DeployCGOOG is Script {
    string constant mintSourceFile = "./functions/sources/goog/buyGoog.js";
    string constant redeemSourceFile = "./functions/sources/goog/sellGoog.js";

    uint64 immutable subId = 349;
    bytes32 immutable donId = 0x66756e2d706f6c79676f6e2d616d6f792d310000000000000000000000000000;
    uint64 secretVersion = 1726912502;
    uint8 secretSlot = 0;
    address immutable USDC_ADDRESS = 0x96182684ae05EC30A3c2644c6CB9F3B9e6A8e89B;
    address immutable GOOG_PRICE_FEED = 0xF8e2648F3F157D972198479D5C7f0D721657Af67;
    address immutable USDC_PRICE_FEED = 0x1b8739bB4CdF0089d07097A9Ae5Bd274b29C6F16;

    function run() external {

        string memory mintSource = vm.readFile(mintSourceFile);
        string memory redeemSource = vm.readFile(redeemSourceFile);

        vm.startBroadcast();
        CGOOG cGOOG = new CGOOG(subId,mintSource,redeemSource,donId,GOOG_PRICE_FEED,USDC_PRICE_FEED,USDC_ADDRESS,secretVersion,secretSlot);
        vm.stopBroadcast();
        console2.log(address(cGOOG));
    }
}