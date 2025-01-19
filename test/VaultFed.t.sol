// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {VaultFed} from "../src/VaultFed.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/tokens/ERC4626.sol";

contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MTK", 18) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function removeApproval(address owner, address spender) public {
        allowance[owner][spender] = 0;
    }
}

contract MockVault is ERC4626 {

    constructor() ERC4626(new MockToken(), "MockVault", "MockVault") {}

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}

contract VaultFedTest is Test {
    MockVault public mockVault;
    VaultFed public vaultFed;
    address public GOV = address(0x1);
    address public CHAIR = address(0x2);
    address public PENDING_GOV = address(0x3);
    function setUp() public {
        mockVault = new MockVault();
        vm.chainId(1);
        vaultFed = new VaultFed(address(mockVault), GOV, CHAIR);
    }

    function test_constructor() public view {
        assertEq(address(vaultFed.vault()), address(mockVault));
        assertEq(vaultFed.gov(), GOV);
        assertEq(vaultFed.chair(), CHAIR);
        assertEq(address(vaultFed.dola()), address(mockVault.asset()));
        assertEq(mockVault.asset().allowance(address(vaultFed), address(mockVault)), type(uint).max);
    }

    function test_setPendingGov() public {
        vm.prank(GOV);
        vaultFed.setPendingGov(PENDING_GOV);
        assertEq(vaultFed.pendingGov(), PENDING_GOV);
    }

    function test_setPendingGov_notGov() public {
        vm.prank(address(0x4));
        vm.expectRevert("Only gov can call this");
        vaultFed.setPendingGov(PENDING_GOV);
    }

    function test_acceptGov() public {
        test_setPendingGov();
        vm.prank(PENDING_GOV);
        vaultFed.acceptGov();
        assertEq(vaultFed.gov(), PENDING_GOV);
        assertEq(vaultFed.pendingGov(), address(0));
    }

    function test_acceptGov_notPendingGov() public {
        test_setPendingGov();
        vm.prank(address(0x4));
        vm.expectRevert("NOT PENDING GOV");
        vaultFed.acceptGov();
    }

    function test_setChair() public {   
        vm.prank(GOV);
        vaultFed.setChair(CHAIR);
        assertEq(vaultFed.chair(), CHAIR);
    }

    function test_setChair_notGov() public {
        vm.prank(address(0x4));
        vm.expectRevert("Only gov can call this");
        vaultFed.setChair(CHAIR);
    }

    function test_resign() public {
        vm.prank(CHAIR);
        vaultFed.resign();
        assertEq(vaultFed.chair(), address(0));
    }

    function test_resign_notChair() public {
        vm.prank(address(0x4));
        vm.expectRevert("NOT PERMISSIONED");
        vaultFed.resign();
    }

    function test_setSupplyCap() public {
        vm.prank(GOV);
        vaultFed.setSupplyCap(1000);
        assertEq(vaultFed.supplyCap(), 1000);
    }

    function test_setSupplyCap_notGov() public {
        vm.prank(address(0x4));
        vm.expectRevert("Only gov can call this");
        vaultFed.setSupplyCap(1000);
    }

    function test_expansion() public {
        vm.prank(GOV);
        vaultFed.setSupplyCap(100);
        vm.prank(CHAIR);
        vaultFed.expansion(100);
        assertEq(vaultFed.supply(), 100);
        assertEq(mockVault.balanceOf(address(vaultFed)), 100);
    }

    function test_expansion_supplyCapExceeded() public {
        // set supply cap to 0 by default
        vm.prank(CHAIR);
        vm.expectRevert("Supply cap exceeded");
        vaultFed.expansion(100);
    }

    function test_expansion_notChair() public {
        vm.prank(address(0x4));
        vm.expectRevert("NOT PERMISSIONED");
        vaultFed.expansion(100);
    }

    function test_contraction() public {
        test_expansion();
        vm.prank(CHAIR);
        vaultFed.contraction(100);
        assertEq(vaultFed.supply(), 0);
        assertEq(mockVault.balanceOf(address(vaultFed)), 0);
    }

    function test_contraction_notChair() public {
        vm.prank(address(0x4));
        vm.expectRevert("NOT PERMISSIONED");
        vaultFed.contraction(100);
    }

    function test_contractAll() public {
        test_expansion();
        vm.prank(CHAIR);
        vaultFed.contractAll();
        assertEq(vaultFed.supply(), 0);
        assertEq(mockVault.balanceOf(address(vaultFed)), 0);
    }

    function test_contractAll_notChair() public {
        vm.prank(address(0x4));
        vm.expectRevert("NOT PERMISSIONED");
        vaultFed.contractAll();
    }

    function test_takeProfit() public {
        test_expansion();
        vm.prank(CHAIR);
        // mint 100 profit to the vault
        MockToken dola = MockToken(address(mockVault.asset()));
        dola.mint(address(mockVault), 100);
        vm.prank(CHAIR);
        vaultFed.takeProfit();
        assertEq(dola.balanceOf(GOV), 100);
        assertEq(dola.balanceOf(address(mockVault)), 100);
        assertEq(mockVault.convertToAssets(mockVault.balanceOf(address(vaultFed))), 100);
        assertEq(mockVault.totalAssets(), 100);
    }

    function test_sweep() public {
        test_expansion();
        vm.prank(GOV);
        vaultFed.sweep(address(mockVault));
        assertEq(mockVault.balanceOf(GOV), 100);
        assertEq(mockVault.balanceOf(address(vaultFed)), 0);
    }

    function test_sweep_notGov() public {
        vm.prank(address(0x4));
        vm.expectRevert("Only gov can call this");
        vaultFed.sweep(address(mockVault));
    }

    function test_reapprove() public {
        MockToken dola = MockToken(address(mockVault.asset()));
        dola.removeApproval(address(vaultFed), address(mockVault));
        assertEq(dola.allowance(address(vaultFed), address(mockVault)), 0);
        vaultFed.reapprove();
        assertEq(dola.allowance(address(vaultFed), address(mockVault)), type(uint).max);
    }

    function test_repayDebt() public {
        test_expansion();
        MockToken dola = MockToken(address(mockVault.asset()));
        // mint 100 to the test
        dola.mint(address(this), 100);
        // repay 100 debt, freeing 100 as profits
        dola.approve(address(vaultFed), 100);
        vaultFed.repayDebt(100);
        assertEq(dola.balanceOf(address(this)), 0);
        assertEq(vaultFed.supply(), 0);
        assertEq(mockVault.totalAssets(), 100);
        assertEq(mockVault.balanceOf(address(vaultFed)), 100);
        // taking profit now results in 100 profit
        vaultFed.takeProfit();
        assertEq(dola.balanceOf(GOV), 100);
        assertEq(dola.balanceOf(address(mockVault)), 0);
        assertEq(mockVault.convertToAssets(mockVault.balanceOf(address(vaultFed))), 0);
        assertEq(mockVault.totalAssets(), 0);
    }
}
