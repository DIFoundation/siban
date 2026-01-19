// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";

contract Donation {
    address public owner;
    IERC20 public usdtToken;

    // Official USDT BEP20 address on BNB Chain (Binance-Peg BSC-USD)
    address private constant OFFICIAL_USDT_BSC = 0x55d398326f99059fF775485246999027B3197955;
    
    mapping(address => uint256) public donations;
    uint256 public totalDonationsReceived;

    event DonationReceived(
        address indexed donor, 
        uint256 amount, 
        uint256 timestamp,
        string message
    );
    event USDTAddressUpdated(address indexed oldAddress, address indexed newAddress);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FundsWithdrawn(address indexed recipient, uint256 amount, uint256 timestamp);

    constructor(address _owner) {
        require(_owner != address(0), "Invalid owner address");
        owner = _owner;
        usdtToken = IERC20(OFFICIAL_USDT_BSC);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // -----------------------------
    // DONATION FUNCTIONS
    // -----------------------------
    
    /**
     * @notice Donate USDT to the contract
     * @param amount Amount of USDT to donate (in smallest unit, 6 decimals for USDT)
     * @param message Optional message from donor
     */
    function donate(uint256 amount, string calldata message) external {
        require(amount > 0, "Amount must be > 0");
        
        // Transfer USDT from donor to contract
        require(
            usdtToken.transferFrom(msg.sender, address(this), amount),
            "USDT transfer failed"
        );

        // Update records
        donations[msg.sender] += amount;
        totalDonationsReceived += amount;
        
        emit DonationReceived(msg.sender, amount, block.timestamp, message);
    }

    /**
     * @notice Simple donation without message
     * @param amount Amount of USDT to donate
     */
    function donateSimple(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        
        require(
            usdtToken.transferFrom(msg.sender, address(this), amount),
            "USDT transfer failed"
        );

        donations[msg.sender] += amount;
        totalDonationsReceived += amount;
        
        emit DonationReceived(msg.sender, amount, block.timestamp, "");
    }

    // -----------------------------
    // ADMIN FUNCTIONS
    // -----------------------------
    
    /**
     * @notice Update USDT token address (emergency use only)
     * @dev Should only be used if USDT migrates to a new contract
     */
    function updateUSDTAddress(address newUSDTAddress) external onlyOwner {
        require(newUSDTAddress != address(0), "Invalid address");
        require(newUSDTAddress != address(usdtToken), "Same address");
        
        address oldAddress = address(usdtToken);
        usdtToken = IERC20(newUSDTAddress);
        
        emit USDTAddressUpdated(oldAddress, newUSDTAddress);
    }

    /**
     * @notice Withdraw specific amount of USDT to a wallet
     * @param wallet Recipient address
     * @param amount Amount to withdraw
     */
    function withdrawUSDT(address wallet, uint256 amount) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        require(amount > 0, "Amount must be > 0");
        
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance >= amount, "Insufficient balance");
        
        require(usdtToken.transfer(wallet, amount), "Transfer failed");
        
        emit FundsWithdrawn(wallet, amount, block.timestamp);
    }

    /**
     * @notice Withdraw all USDT balance to a wallet
     * @param wallet Recipient address
     */
    function withdrawAllUSDT(address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        
        uint256 balance = usdtToken.balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        
        require(usdtToken.transfer(wallet, balance), "Transfer failed");
        
        emit FundsWithdrawn(wallet, balance, block.timestamp);
    }

    /**
     * @notice Transfer contract ownership to new address
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        require(newOwner != owner, "Already owner");
        
        address oldOwner = owner;
        owner = newOwner;
        
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // -----------------------------
    // VIEW FUNCTIONS
    // -----------------------------
    
    /**
     * @notice Get current USDT balance of the contract
     * @return Current balance in USDT (6 decimals)
     */
    function getContractBalance() external view returns (uint256) {
        return usdtToken.balanceOf(address(this));
    }

    /**
     * @notice Get total donations made by a specific user
     * @param user Address of the donor
     * @return Total amount donated
     */
    function getUserDonations(address user) external view returns (uint256) {
        return donations[user];
    }

    /**
     * @notice Get the current USDT token address being used
     * @return Address of the USDT token contract
     */
    function getUSDTAddress() external view returns (address) {
        return address(usdtToken);
    }

    /**
     * @notice Check if current USDT address matches official BSC USDT
     * @return true if using official USDT address
     */
    function isUsingOfficialUSDT() external view returns (bool) {
        return address(usdtToken) == OFFICIAL_USDT_BSC;
    }

    /**
     * @notice Get total donations received by contract (all time)
     * @return Total amount received
     */
    function getTotalDonationsReceived() external view returns (uint256) {
        return totalDonationsReceived;
    }
}