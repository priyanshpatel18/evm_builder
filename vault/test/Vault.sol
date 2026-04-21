// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract MockToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "no balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(balanceOf[from] >= amount, "no balance");
        require(allowance[from][msg.sender] >= amount, "no allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}

contract VaultTest is Test {
    Vault vault;

    MockToken usdc;
    MockToken eurc;

    address user = address(1);

    function setUp() public {
        vault = new Vault();

        usdc = new MockToken("USDC", "USDC");
        eurc = new MockToken("EURC", "EURC");

        // add tokens to whitelist
        vault.addToken(address(usdc));
        vault.addToken(address(eurc));

        // mint tokens
        usdc.mint(user, 100 ether);
        eurc.mint(user, 200 ether);

        // approvals
        vm.startPrank(user);
        usdc.approve(address(vault), 100 ether);
        eurc.approve(address(vault), 200 ether);
        vm.stopPrank();
    }

    function testDepositMultipleTokens() public {
        vm.startPrank(user);

        vault.deposit(address(usdc), 50 ether);
        vault.deposit(address(eurc), 100 ether);

        vm.stopPrank();

        assertEq(vault.balanceOf(user, address(usdc)), 50 ether);
        assertEq(vault.balanceOf(user, address(eurc)), 100 ether);
    }

    function testWithdrawMultipleTokens() public {
        vm.startPrank(user);

        vault.deposit(address(usdc), 50 ether);
        vault.deposit(address(eurc), 100 ether);

        vault.withdraw(address(usdc), 20 ether);
        vault.withdraw(address(eurc), 40 ether);

        vm.stopPrank();

        assertEq(vault.balanceOf(user, address(usdc)), 30 ether);
        assertEq(vault.balanceOf(user, address(eurc)), 60 ether);

        assertEq(usdc.balanceOf(user), 70 ether);
        assertEq(eurc.balanceOf(user), 140 ether);
    }

    function test_RevertIf_UnsupportedToken() public {
        MockToken fake = new MockToken("FAKE", "FAKE");

        vm.startPrank(user);

        fake.mint(user, 100 ether);
        fake.approve(address(vault), 100 ether);

        vm.expectRevert("TOKEN_NOT_SUPPORTED");
        vault.deposit(address(fake), 10 ether);

        vm.stopPrank();
    }

    function test_RevertIf_WithdrawTooMuch() public {
        vm.startPrank(user);

        vault.deposit(address(usdc), 10 ether);

        vm.expectRevert("INSUFFICIENT_BALANCE");
        vault.withdraw(address(usdc), 20 ether);

        vm.stopPrank();
    }
}
