// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vault {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => uint256)) public balanceOf;
    mapping(address => bool) public isSupportedToken;

    address public owner;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event TokenAdded(address token);
    event TokenRemoved(address token);

    /// @notice Modifier to only allow the owner to call a function
    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");  
        _;
    }

    constructor() {
        /// @notice Set the owner of the vault
        owner = msg.sender;
    }

    /// @notice Add a token to the vault
    function addToken(address token) external onlyOwner {
        isSupportedToken[token] = true;
        emit TokenAdded(token);
    }

    /// @notice Remove a token from the vault
    function removeToken(address token) external onlyOwner {
        isSupportedToken[token] = false;
        emit TokenRemoved(token);
    }

    /// @notice Deposit tokens into vault
    function deposit(address token, uint256 amount) external {
        require(isSupportedToken[token], "TOKEN_NOT_SUPPORTED");
        require(amount > 0, "ZERO_AMOUNT");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        balanceOf[msg.sender][token] += amount;

        emit Deposit(msg.sender, token, amount);
    }

    /// @notice Withdraw tokens from vault
    function withdraw(address token, uint256 amount) external {
        require(amount > 0, "ZERO_AMOUNT");
        require(balanceOf[msg.sender][token] >= amount, "INSUFFICIENT_BALANCE");

        balanceOf[msg.sender][token] -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }
}
