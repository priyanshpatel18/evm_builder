// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Escrow {
    using SafeERC20 for IERC20;

    enum Status {
        NONE,
        OPEN,
        FILLED,
        CANCELLED
    }

    struct Order {
        address maker;
        address tokenGive;
        uint256 amountGive;
        address tokenWant;
        uint256 amountWant;
        uint256 expiration;
        Status status;
    }

    uint256 public nextOrderId;
    mapping(uint256 => Order) public orders;

    event OrderCreated(
        uint256 indexed orderId,
        address indexed maker,
        address tokenGive,
        uint256 amountGive,
        address tokenWant,
        uint256 amountWant,
        uint256 expiration
    );

    event OrderFilled(uint256 indexed id, address indexed taker);
    event OrderCancelled(uint256 indexed id);

    /// @notice Create a new order
    function make(
        address tokenGive,
        uint256 amountGive,
        address tokenWant,
        uint256 amountWant,
        uint256 expiration
    ) external returns (uint256 id) {
        require(amountGive > 0 && amountWant > 0, "INVALID_AMOUNT");
        require(block.timestamp < expiration, "ORDER_EXPIRED");

        IERC20(tokenGive).safeTransferFrom(msg.sender, address(this), amountGive);

        id = nextOrderId++;

        orders[id] = Order({
            maker: msg.sender,
            tokenGive: tokenGive,
            amountGive: amountGive,
            tokenWant: tokenWant,
            amountWant: amountWant,
            expiration: expiration,
            status: Status.OPEN
        });

        emit OrderCreated(id, msg.sender, tokenGive, amountGive, tokenWant, amountWant, expiration);
    }

    /// @notice Fill an order
    function take(uint256 id) external {
        Order storage o = orders[id];

        require(o.status == Status.OPEN, "NOT_OPEN");
        require(block.timestamp < o.expiration, "ORDER_EXPIRED");
        require(o.maker != msg.sender, "MAKER_CANNOT_TAKE");

        o.status = Status.FILLED;

        // taker → maker
        IERC20(o.tokenWant).safeTransferFrom(msg.sender, o.maker, o.amountWant);

        // contract → taker
        IERC20(o.tokenGive).safeTransfer(msg.sender, o.amountGive);

        emit OrderFilled(id, msg.sender);
    }

    /// @notice Cancel an order
    function refund(uint256 id) external {
        Order storage o = orders[id];

        require(o.status == Status.OPEN, "NOT_OPEN");
        require(o.maker == msg.sender, "NOT_MAKER");

        // Update order status
        o.status = Status.CANCELLED;

        // Transfer taker funds
        IERC20(o.tokenGive).safeTransfer(msg.sender, o.amountGive);

        // Emit event
        emit OrderCancelled(id);
    }
}
