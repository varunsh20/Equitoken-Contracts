// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "../lib/forge-std/src/Script.sol";
import { CMETA } from "../src/CMETA.sol";
import {console2} from "../lib/forge-std/src/console2.sol";

contract DeployCMETA is Script {
    string constant mintSourceFile = "./functions/sources/meta/buyMeta.js";
    string constant redeemSourceFile = "./functions/sources/meta/sellMeta.js";

    uint64 immutable subId = 349;
    bytes32 immutable donId = 0x66756e2d706f6c79676f6e2d616d6f792d310000000000000000000000000000;
    uint64 secretVersion = 1726912502;
    uint8 secretSlot = 0;
    address immutable USDC_ADDRESS = 0x96182684ae05EC30A3c2644c6CB9F3B9e6A8e89B;
    address immutable META_PRICE_FEED = 0xe7656e23fE8077D438aEfbec2fAbDf2D8e070C4f;
    address immutable USDC_PRICE_FEED = 0x1b8739bB4CdF0089d07097A9Ae5Bd274b29C6F16;

    function run() external {

        string memory mintSource = vm.readFile(mintSourceFile);
        string memory redeemSource = vm.readFile(redeemSourceFile);

        vm.startBroadcast();
        CMETA cMETA = new CMETA(subId,mintSource,redeemSource,donId,META_PRICE_FEED,USDC_PRICE_FEED,USDC_ADDRESS,secretVersion,secretSlot);
        vm.stopBroadcast();
        console2.log(address(cMETA));
    }
}