// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";

contract Donation {
    address public owner;
    IERC20 public usdtToken;

    mapping(address => uint256) public donations;

    event DonationReceived(address indexed donor, uint256 amount, uint256 timestamp);
    event USDTAddressUpdated(address indexed oldAddress, address indexed newAddress);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address _usdtToken, address _owner) {
        owner = _owner;
        usdtToken = IERC20(_usdtToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // -----------------------------
    // DONATION FUNCTIONS
    // -----------------------------
    function donate(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(
            usdtToken.transferFrom(msg.sender, address(this), amount),
            "USDT transfer failed"
        );

        donations[msg.sender] += amount;
        emit DonationReceived(msg.sender, amount, block.timestamp);
    }

    // -----------------------------
    // ADMIN FUNCTIONS
    // -----------------------------
    function updateUSDTAddress(address newUSDTAddress) external onlyOwner {
        require(newUSDTAddress != address(0), "Invalid address");
        address oldAddress = address(usdtToken);
        usdtToken = IERC20(newUSDTAddress);
        emit USDTAddressUpdated(oldAddress, newUSDTAddress);
    }

    function withdrawUSDT(address wallet, uint256 amount) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance >= amount, "Insufficient balance");
        require(usdtToken.transfer(wallet, amount), "Transfer failed");
    }

    function withdrawAllUSDT(address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance > 0, "No balance");
        require(usdtToken.transfer(wallet, balance), "Transfer failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // -----------------------------
    // VIEW FUNCTIONS
    // -----------------------------
    function getContractBalance() external view returns (uint256) {
        return usdtToken.balanceOf(address(this));
    }

    function getUserDonations(address user) external view returns (uint256) {
        return donations[user];
    }
}
