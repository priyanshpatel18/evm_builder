// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Escrow.sol";

contract MockToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "NO_BAL");
        require(allowance[from][msg.sender] >= amount, "NO_ALLOW");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}

contract EscrowTest is Test {
    Escrow escrow;
    MockToken tokenA;
    MockToken tokenB;

    address maker = address(1);
    address taker = address(2);

    function setUp() public {
        escrow = new Escrow();
        tokenA = new MockToken();
        tokenB = new MockToken();

        tokenA.mint(maker, 100 ether);
        tokenB.mint(taker, 200 ether);

        vm.prank(maker);
        tokenA.approve(address(escrow), 100 ether);

        vm.prank(taker);
        tokenB.approve(address(escrow), 200 ether);
    }

    function testMakeAndTake() public {
        uint256 expiry = block.timestamp + 1 days;

        vm.prank(maker);
        uint256 id = escrow.make(
            address(tokenA),
            50 ether,
            address(tokenB),
            100 ether,
            expiry
        );

        vm.prank(taker);
        escrow.take(id);

        assertEq(tokenA.balanceOf(taker), 50 ether);
        assertEq(tokenB.balanceOf(maker), 100 ether);
    }

    function testRefund() public {
        uint256 expiry = block.timestamp + 1 days;

        vm.prank(maker);
        uint256 id = escrow.make(
            address(tokenA),
            50 ether,
            address(tokenB),
            100 ether,
            expiry
        );

        vm.prank(maker);
        escrow.refund(id);

        assertEq(tokenA.balanceOf(maker), 100 ether);
    }

    function test_RevertIf_ExpiredOrder() public {
        uint256 expiry = block.timestamp + 1;

        vm.prank(maker);
        uint256 id = escrow.make(
            address(tokenA),
            50 ether,
            address(tokenB),
            100 ether,
            expiry
        );

        vm.warp(block.timestamp + 2);

        vm.expectRevert("ORDER_EXPIRED");
        vm.prank(taker);
        escrow.take(id);
    }

    function test_RevertIf_NotOpen() public {
        uint256 expiry = block.timestamp + 1 days;

        vm.prank(maker);
        uint256 id = escrow.make(
            address(tokenA),
            50 ether,
            address(tokenB),
            100 ether,
            expiry
        );

        vm.prank(maker);
        escrow.refund(id);

        vm.expectRevert("NOT_OPEN");
        vm.prank(taker);
        escrow.take(id);
    }
}