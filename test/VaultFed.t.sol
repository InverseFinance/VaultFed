// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {VaultFed} from "../src/VaultFed.sol";

contract MockVault {
    
}

contract VaultFedTest is Test {
    MockVault public mockVault;
    VaultFed public vaultFed;
    address public GOV = address(0x1);
    address public CHAIR = address(0x2);

    function setUp() public {
        mockVault = new MockVault();
        vm.chainId(1);
        vaultFed = new VaultFed(address(mockVault), GOV, CHAIR);
    }

    function test_constructor() public {
        assertEq(address(vaultFed.vault()), address(mockVault));
        assertEq(vaultFed.gov(), GOV);
        assertEq(vaultFed.chair(), CHAIR);
    }
}
