// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title LendingProtocol (ETH-Only Demo)
 * @notice A simple lending/borrowing protocol where users can:
 *         - Supply ETH to earn interest
 *         - Borrow ETH against supplied collateral
 *         - Repay loans
 *         Interest accrues over time using a simple APY formula.
 */
contract LendingProtocol {

    /**
     * @notice Represents a lending market for a specific token (ETH in this demo)
     * @dev Uses mappings inside the struct to store per-user balances and last update times.
     */
    struct Market {
        uint256 totalSupply;       // Total ETH supplied to this market
        uint256 totalBorrow;       // Total ETH borrowed from this market
        uint256 supplyRate;        // Annual supply interest rate (scaled by 1e18)
        uint256 borrowRate;        // Annual borrow interest rate (scaled by 1e18)
        uint256 collateralFactor;  // Collateral factor in basis points (e.g., 7500 = 75%)
        mapping(address => uint256) supplyBalance; // User supply balances
        mapping(address => uint256) borrowBalance; // User borrow balances
        mapping(address => uint256) lastUpdate;    // Last timestamp interest was updated for user
    }
    
    // All markets, keyed by token address (ETH = address(0))
    mapping(address => Market) public markets;

    // Supported token list (ETH only in this demo)
    mapping(address => bool) public supportedTokens;

    // Token prices in USD, scaled by PRICE_PRECISION
    mapping(address => uint256) public tokenPrices;

    // Contract owner (can update token prices)
    address public owner;

    // Constants for fixed-point precision
    uint256 public constant RATE_PRECISION = 1e18;   // For interest rate calculations
    uint256 public constant PRICE_PRECISION = 1e8;   // For token prices (e.g., Chainlink format)
    
    // Events for logging protocol actions
    event Supplied(address indexed user, address indexed token, uint256 amount);
    event Borrowed(address indexed user, address indexed token, uint256 amount);
    event Repaid(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    
    // Restrict functions to contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        
        // Initialize ETH market with default parameters
        supportedTokens[address(0)] = true; // Support ETH
        tokenPrices[address(0)] = 2000 * PRICE_PRECISION; // ETH price = $2000
        markets[address(0)].collateralFactor = 7500; // 75% max borrow limit
        markets[address(0)].supplyRate = 2e16; // 2% APY
        markets[address(0)].borrowRate = 5e16; // 5% APY
    }
    
    /**
     * @notice Updates accrued interest for a user's supply and borrow positions
     * @dev Uses simple interest formula based on elapsed time since last update.
     */
    function updateInterest(address token, address user) internal {
        Market storage market = markets[token];
        
        // If first interaction, set last update timestamp
        if (market.lastUpdate[user] == 0) {
            market.lastUpdate[user] = block.timestamp;
            return;
        }
        
        uint256 timeElapsed = block.timestamp - market.lastUpdate[user];
        
        // Accrue supply interest (if user has supplied)
        if (market.supplyBalance[user] > 0) {
            uint256 interest = (market.supplyBalance[user] * market.supplyRate * timeElapsed)
                / (365 days * RATE_PRECISION);
            market.supplyBalance[user] += interest;
        }
        
        // Accrue borrow interest (if user has borrowed)
        if (market.borrowBalance[user] > 0) {
            uint256 interest = (market.borrowBalance[user] * market.borrowRate * timeElapsed)
                / (365 days * RATE_PRECISION);
            market.borrowBalance[user] += interest;
        }
        
        // Update last interaction time
        market.lastUpdate[user] = block.timestamp;
    }
    
    /**
     * @notice Supply ETH to the protocol to earn interest
     */
    function supply(address token) external payable {
        require(supportedTokens[token], "Token not supported");
        require(msg.value > 0, "Amount must be greater than 0");
        
        updateInterest(token, msg.sender);
        
        Market storage market = markets[token];
        market.supplyBalance[msg.sender] += msg.value;
        market.totalSupply += msg.value;
        
        emit Supplied(msg.sender, token, msg.value);
    }
    
    /**
     * @notice Withdraw supplied ETH (if collateral allows)
     */
    function withdraw(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        
        updateInterest(token, msg.sender);
        
        Market storage market = markets[token];
        require(market.supplyBalance[msg.sender] >= amount, "Insufficient supply balance");
        
        market.supplyBalance[msg.sender] -= amount;
        market.totalSupply -= amount;
        
        payable(msg.sender).transfer(amount);
        
        emit Withdrawn(msg.sender, token, amount);
    }
    
    /**
     * @notice Borrow ETH using supplied collateral
     * @dev Ensures borrow limit is respected based on collateral factor and token price.
     */
    function borrow(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        
        updateInterest(token, msg.sender);
        
        // Calculate updated borrow and collateral values
        uint256 collateralValue = getAccountCollateralValue(msg.sender);
        uint256 borrowValue = getAccountBorrowValue(msg.sender)
            + (amount * tokenPrices[token]) / PRICE_PRECISION;
        
        // Borrow limit check
        require(
            borrowValue * 10000 <= collateralValue * markets[token].collateralFactor,
            "Insufficient collateral"
        );
        
        Market storage market = markets[token];
        market.borrowBalance[msg.sender] += amount;
        market.totalBorrow += amount;
        
        payable(msg.sender).transfer(amount);
        
        emit Borrowed(msg.sender, token, amount);
    }
    
    /**
     * @notice Repay borrowed ETH
     * @dev Refunds excess ETH sent.
     */
    function repay(address token) external payable {
        require(supportedTokens[token], "Token not supported");
        
        updateInterest(token, msg.sender);
        
        Market storage market = markets[token];
        uint256 borrowBalance = market.borrowBalance[msg.sender];
        uint256 repayAmount = msg.value > borrowBalance ? borrowBalance : msg.value;
        
        market.borrowBalance[msg.sender] -= repayAmount;
        market.totalBorrow -= repayAmount;
        
        // Refund any overpayment
        if (msg.value > repayAmount) {
            payable(msg.sender).transfer(msg.value - repayAmount);
        }
        
        emit Repaid(msg.sender, token, repayAmount);
    }
    
    /**
     * @notice Returns total USD value of supplied collateral
     */
    function getAccountCollateralValue(address user) public view returns (uint256) {
        uint256 totalValue = 0;
        
        // Only ETH is supported here
        Market storage market = markets[address(0)];
        totalValue += (market.supplyBalance[user] * tokenPrices[address(0)]) / PRICE_PRECISION;
        
        return totalValue;
    }
    
    /**
     * @notice Returns total USD value of borrowed assets
     */
    function getAccountBorrowValue(address user) public view returns (uint256) {
        uint256 totalValue = 0;
        
        // Only ETH is supported here
        Market storage market = markets[address(0)];
        totalValue += (market.borrowBalance[user] * tokenPrices[address(0)]) / PRICE_PRECISION;
        
        return totalValue;
    }
    
    /**
     * @notice Returns user's balances and account health data
     */
    function getAccountInfo(address user)
        external
        view
        returns (
            uint256 supplyBalance,
            uint256 borrowBalance,
            uint256 collateralValue,
            uint256 borrowValue
        )
    {
        Market storage market = markets[address(0)];
        return (
            market.supplyBalance[user],
            market.borrowBalance[user],
            getAccountCollateralValue(user),
            getAccountBorrowValue(user)
        );
    }
    
    /**
     * @notice Owner can update mock token prices
     */
    function updateTokenPrice(address token, uint256 price) external onlyOwner {
        tokenPrices[token] = price;
    }
}
