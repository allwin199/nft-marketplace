// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract DeployNftMarketplace is Script {
    function run() external returns (NFTMarketplace) {
        vm.startBroadcast();
        NFTMarketplace nftMarketplace = new NFTMarketplace();
        vm.stopBroadcast();
        return nftMarketplace;
    }
}
