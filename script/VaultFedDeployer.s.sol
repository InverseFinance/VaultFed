// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {VaultFed} from "../src/VaultFed.sol";

contract VaultFedDeployer is Script {
    VaultFed public vaultFed;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        //vaultFed = new VaultFed();

        vm.stopBroadcast();
    }
}
