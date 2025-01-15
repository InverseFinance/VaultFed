// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {VaultFed} from "../src/VaultFed.sol";

contract VaultFedDeployer is Script {
    VaultFed public vaultFed;

    function setUp() public {}

    function run() public {
        
        vm.startBroadcast();

        address vault = 0x31426271449F60d37Cc5C9AEf7bD12aF3BdC7A94; // Gearbox Dola Vault
        address gov = 0x926dF14a23BE491164dCF93f4c468A50ef659D5B;
        address chair = 0x8F97cCA30Dbe80e7a8B462F1dD1a51C32accDfC8;

        new VaultFed(vault, gov, chair);

        vm.stopBroadcast();
    }
}
