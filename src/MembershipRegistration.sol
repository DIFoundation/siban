// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";

contract MembershipRegistration {
    address public owner;
    IERC20 public usdtToken;

    // Max value for uint256 to represent "forever" or "lifetime"
    uint256 private constant LIFETIME_EXPIRY = type(uint256).max; 

    struct Category {
        string name;
        bool isActive;
        uint256 createdAt;
    }

    struct Tier {
        string name;
        uint256 price;
        uint8 categoryId;
        bool isActive;
        // 0 for Lifetime/Donation-based, > 0 for Annual (e.g., 365 for a year)
        uint32 durationInDays;
        bool isDonationBased; // New field to identify donation tiers
    }

    mapping(uint8 => Category) public categories;
    mapping(uint256 => Tier) public tiers;
    // Maps user address to the tier ID and its expiration timestamp
    mapping(address => mapping(uint256 => uint256)) public userMembershipExpiry; 

    uint8 public categoryCount;
    uint256 public tierCount;

    event MembershipRegistered(
        address indexed user,
        uint256 indexed tierId,
        string tierName,
        uint8 categoryId,
        string categoryName,
        uint256 amount,
        string email,
        uint256 expiryTimestamp,
        uint256 timestamp
    );
    event CategoryCreated(uint8 indexed categoryId, string name);
    event CategoryUpdated(uint8 indexed categoryId, string name, bool isActive);
    event TierCreated(uint256 indexed tierId, string name, uint8 categoryId, uint256 price, uint32 durationInDays, bool isDonationBased);
    event TierUpdated(uint256 indexed tierId, string name, uint256 price, bool isActive, uint32 durationInDays);
    event USDTAddressUpdated(address indexed oldAddress, address indexed newAddress);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address _usdtToken, address _owner) {
        owner = _owner;
        usdtToken = IERC20(_usdtToken);

        // CATEGORY IMPLEMENTATION
        _createCategory("Stakeholder Circle"); // ID 1
        _createCategory("Community Node"); // ID 2
        _createCategory("Student Node"); // ID 3

        // ====================================
        // STAKEHOLDER CIRCLE TIERS (Category 1)
        // ====================================
        // Prices in USDT (6 decimals): price * 10**6
        
        _createTier("Enthusiast", 20 * 10**6, 1, 365, false);
        _createTier("Expert", 50 * 10**6, 1, 365, false);
        _createTier("Individual Crypto Trader", 100 * 10**6, 1, 365, false);
        _createTier("Professional Firms & Consultancy", 200 * 10**6, 1, 365, false);
        _createTier("DeFi Platform", 500 * 10**6, 1, 365, false);
        _createTier("Local Digital Asset Exchange", 250 * 10**6, 1, 365, false);
        _createTier("Global Digital Asset Exchange", 500 * 10**6, 1, 365, false);
        _createTier("Local Peer-to-Peer Digital Assets Platform", 250 * 10**6, 1, 365, false);
        _createTier("Global Peer-to-Peer Digital Assets Platform", 500 * 10**6, 1, 365, false);
        _createTier("Local Over-the-Counter Digital Asset Service", 250 * 10**6, 1, 365, false);
        _createTier("Global Over-the-Counter Digital Assets Provider", 500 * 10**6, 1, 365, false);
        _createTier("Technical Developers", 200 * 10**6, 1, 365, false);
        _createTier("Venture Capitalists", 1000 * 10**6, 1, 365, false);
        _createTier("Payment Solution Service Providers", 1000 * 10**6, 1, 365, false);
        _createTier("Payment Gateways Providers", 1000 * 10**6, 1, 365, false);
        _createTier("Mobile Money Operators", 500 * 10**6, 1, 365, false);
        _createTier("Payment Service Terminal Providers", 1000 * 10**6, 1, 365, false);
        _createTier("Bill Payments Platforms and e-Wallets", 1000 * 10**6, 1, 365, false);
        _createTier("Merchant Payments & Services", 500 * 10**6, 1, 365, false);
        _createTier("Cybersecurity & Data Protection Services", 250 * 10**6, 1, 365, false);
        _createTier("Blockchain Solutions Provider", 250 * 10**6, 1, 365, false);
        _createTier("Identity Verification Services", 250 * 10**6, 1, 365, false);
        _createTier("KYC/AML/CFT Service Providers (Veri Node)", 250 * 10**6, 1, 365, false);
        _createTier("General IT company", 250 * 10**6, 1, 365, false);
        _createTier("Arts, Media & Entertainment (Creative Node)", 250 * 10**6, 1, 365, false);
        _createTier("NFT Platform", 250 * 10**6, 1, 365, false);
        
        // Donation-based tiers with suggested minimum amounts
        _createTier("Academy, Education & Training", 100 * 10**6, 1, 365, true);
        _createTier("Virtual Asset Regulator", 0, 1, 365, true);
        _createTier("Association & Interest Group", 250 * 10**6, 1, 365, true);
        _createTier("Charities & NGOs", 0, 1, 365, true);
        _createTier("Incubator & Accelerator", 0, 1, 365, true);
        _createTier("Research & Development", 0, 1, 365, true);
        _createTier("Professional Body", 0, 1, 365, true);
        _createTier("Government MDAs", 0, 1, 365, true);

        // ====================================
        // COMMUNITY NODE TIERS (Category 2)
        // ====================================
        // Voluntary donations
        _createTier("Individuals", 0, 2, 365, true);
        _createTier("Organization", 0, 2, 365, true);

        // ====================================
        // STUDENT NODE TIERS (Category 3)
        // ====================================
        _createTier("Undergraduate", 10 * 10**6, 3, 365, false);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // -----------------------------
    // REGISTRATION
    // -----------------------------
    function register(uint256 tierId, string calldata email, uint256 donationAmount) external {
        require(tierId > 0 && tierId <= tierCount, "Invalid tier ID");

        Tier memory tier = tiers[tierId];
        require(tier.isActive, "Tier is not active");
        require(categories[tier.categoryId].isActive, "Category is not active");
        require(bytes(email).length > 0, "Email required");
        
        // Prevents double registration/payment if already active
        require(userMembershipExpiry[msg.sender][tierId] <= block.timestamp, "Membership is already active");

        // PAYMENT LOGIC
        uint256 paymentAmount;
        
        if (tier.isDonationBased) {
            // For donation-based tiers, user can pay any amount >= the suggested minimum
            require(donationAmount >= tier.price, "Donation amount below minimum");
            paymentAmount = donationAmount;
        } else {
            // For fixed-price tiers, must pay exact amount
            require(donationAmount == 0, "Use price field for fixed tiers");
            paymentAmount = tier.price;
        }

        if (paymentAmount > 0) {
            require(
                usdtToken.transferFrom(msg.sender, address(this), paymentAmount),
                "USDT transfer failed"
            );
        }

        // EXPIRY LOGIC
        uint256 expiryTimestamp;
        
        if (tier.durationInDays == 0) {
            expiryTimestamp = LIFETIME_EXPIRY; 
        } else {
            expiryTimestamp = block.timestamp + (uint256(tier.durationInDays) * 1 days);
        }

        userMembershipExpiry[msg.sender][tierId] = expiryTimestamp;

        emit MembershipRegistered(
            msg.sender,
            tierId,
            tier.name,
            tier.categoryId,
            categories[tier.categoryId].name,
            paymentAmount,
            email,
            expiryTimestamp,
            block.timestamp
        );
    }

    // -----------------------------
    // CATEGORY MANAGEMENT
    // -----------------------------
    function createCategory(string calldata name) external onlyOwner {
        _createCategory(name);
    }

    function _createCategory(string memory name) private {
        categoryCount++;
        categories[categoryCount] = Category({
            name: name,
            isActive: true,
            createdAt: block.timestamp
        });
        emit CategoryCreated(categoryCount, name);
    }

    function updateCategory(uint8 categoryId, string calldata name, bool isActive)
        external
        onlyOwner
    {
        require(categoryId > 0 && categoryId <= categoryCount, "Invalid category ID");
        categories[categoryId].name = name;
        categories[categoryId].isActive = isActive;
        emit CategoryUpdated(categoryId, name, isActive);
    }

    // -----------------------------
    // TIER MANAGEMENT
    // -----------------------------
    function createTier(
        string calldata name,
        uint256 price,
        uint8 categoryId,
        uint32 durationInDays,
        bool isDonationBased
    ) external onlyOwner {
        _createTier(name, price, categoryId, durationInDays, isDonationBased);
    }

    function _createTier(
        string memory name,
        uint256 price,
        uint8 categoryId,
        uint32 durationInDays,
        bool isDonationBased
    ) private {
        require(categoryId > 0 && categoryId <= categoryCount, "Invalid category ID");
        tierCount++;
        tiers[tierCount] = Tier({
            name: name,
            price: price,
            categoryId: categoryId,
            isActive: true,
            durationInDays: durationInDays,
            isDonationBased: isDonationBased
        });
        emit TierCreated(tierCount, name, categoryId, price, durationInDays, isDonationBased);
    }

    function updateTier(
        uint256 tierId,
        string calldata name,
        uint256 price,
        uint8 categoryId,
        bool isActive,
        uint32 durationInDays,
        bool isDonationBased
    ) external onlyOwner {
        require(tierId > 0 && tierId <= tierCount, "Invalid tier ID");
        require(categoryId > 0 && categoryId <= categoryCount, "Invalid category ID");

        tiers[tierId].name = name;
        tiers[tierId].price = price; 
        tiers[tierId].categoryId = categoryId;
        tiers[tierId].isActive = isActive;
        tiers[tierId].durationInDays = durationInDays;
        tiers[tierId].isDonationBased = isDonationBased;

        emit TierUpdated(tierId, name, price, isActive, durationInDays);
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
    function getCategory(uint8 categoryId)
        external
        view
        returns (string memory name, bool isActive, uint256 createdAt)
    {
        Category memory cat = categories[categoryId];
        return (cat.name, cat.isActive, cat.createdAt);
    }

    function getTier(uint256 tierId)
        external
        view
        returns (
            string memory name,
            uint256 price,
            uint8 categoryId,
            string memory categoryName,
            bool isActive,
            uint32 durationInDays,
            bool isDonationBased
        )
    {
        Tier memory tier = tiers[tierId];
        return (
            tier.name,
            tier.price,
            tier.categoryId,
            categories[tier.categoryId].name,
            tier.isActive,
            tier.durationInDays,
            tier.isDonationBased
        );
    }

    function isUserMember(address user, uint256 tierId) external view returns (bool) {
        uint256 expiry = userMembershipExpiry[user][tierId];
        return expiry == LIFETIME_EXPIRY || expiry > block.timestamp;
    }
    
    function getMembershipExpiry(address user, uint256 tierId) external view returns (uint256) {
        return userMembershipExpiry[user][tierId];
    }
}