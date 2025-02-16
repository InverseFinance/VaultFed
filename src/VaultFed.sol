// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC4626 {
    function asset() external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function transfer(address to, uint256 value) external returns (bool);
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function mint(address to, uint amount) external;
    function burn(uint amount) external;
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract VaultFed {

    address public gov;
    address public pendingGov;
    address public chair;
    IERC4626 public immutable vault;
    IERC20 public immutable dola;

    uint public supply;
    uint public supplyCap;

    constructor(address _vault, address _gov, address _chair) {
        require(_vault != address(0), "Vault is required");
        require(_gov != address(0), "Gov is required");
        require(_chair != address(0), "Chair is required");
        require(block.chainid == 1, "Must mint DOLA on Mainnet");
        vault = IERC4626(_vault);
        gov = _gov;
        chair = _chair;
        dola = IERC20(vault.asset());
        dola.approve(address(vault), type(uint).max);
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Only gov can call this");
        _;
    }

    modifier onlyChair() {
        require(msg.sender == chair || msg.sender == gov, "NOT PERMISSIONED");
        _;
    }

    function setPendingGov(address _pendingGov) onlyGov external {
        pendingGov = _pendingGov;
        emit NewPendingGov(_pendingGov);
    }

    function acceptGov() external {
        require(msg.sender == pendingGov, "NOT PENDING GOV");
        gov = pendingGov;
        pendingGov = address(0);
        emit NewGov(gov);
    }

    function setChair(address newChair) onlyGov external{
        chair = newChair;
        emit NewChair(newChair);
    }

    function setSupplyCap(uint newSupplyCap) onlyGov external {
        supplyCap = newSupplyCap;
        emit NewSupplyCap(newSupplyCap);
    }

    function resign() onlyChair external {
        chair = address(0);
        emit NewChair(address(0));
    }

    function expansion(uint amount) onlyChair external {
        require(supply + amount <= supplyCap, "Supply cap exceeded");
        supply += amount;
        dola.mint(address(this), amount);
        vault.deposit(amount, address(this));
        emit Expansion(amount);
    }

    function contraction(uint amount) onlyChair external {
        supply -= amount; // reverts when burning profits
        vault.withdraw(amount, address(this), address(this));
        dola.burn(amount);
        emit Contraction(amount);
    }

    function takeProfit() external {
        uint profit = vault.previewRedeem(vault.balanceOf(address(this))) - supply;
        vault.withdraw(profit, gov, address(this));
        emit Profit(profit);
    }

    function sweep(address token) onlyGov external {
        IERC20(token).transfer(gov, IERC20(token).balanceOf(address(this)));
    }

    function reapprove() external {
        dola.approve(address(vault), type(uint).max);
    }

    function repayDebt(uint amount) external {
        supply -= amount; // reverts repaying too much
        dola.transferFrom(msg.sender, address(this), amount);
        dola.burn(amount);
        emit RepayDebt(amount);
    }

    event NewPendingGov(address pendingGov);
    event NewGov(address gov);
    event NewChair(address chair);
    event NewSupplyCap(uint supplyCap);
    event Expansion(uint amount);
    event Contraction(uint amount);
    event Profit(uint amount);
    event RepayDebt(uint amount);
}
