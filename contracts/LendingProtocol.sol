//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract LendingProtocol {
    struct Market {
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 collateralFactor; // 75% = 7500
        mapping(address => uint256) supplyBalance;
        mapping(address => uint256) borrowBalance;
        mapping(address => uint256) lastUpdate;
    }
    
    mapping(address => Market) public markets;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public tokenPrices; // Mock price feed
    
    address public owner;
    uint256 public constant RATE_PRECISION = 1e18;
    uint256 public constant PRICE_PRECISION = 1e8;
    
    event Supplied(address indexed user, address indexed token, uint256 amount);
    event Borrowed(address indexed user, address indexed token, uint256 amount);
    event Repaid(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        
        // Initialize ETH market
        supportedTokens[address(0)] = true;
        tokenPrices[address(0)] = 2000 * PRICE_PRECISION; // $2000
        markets[address(0)].collateralFactor = 7500; // 75%
        markets[address(0)].supplyRate = 2e16; // 2% APY
        markets[address(0)].borrowRate = 5e16; // 5% APY
    }
    
    function updateInterest(address token, address user) internal {
        Market storage market = markets[token];
        
        if (market.lastUpdate[user] == 0) {
            market.lastUpdate[user] = block.timestamp;
            return;
        }
        
        uint256 timeElapsed = block.timestamp - market.lastUpdate[user];
        
        if (market.supplyBalance[user] > 0) {
            uint256 interest = (market.supplyBalance[user] * market.supplyRate * timeElapsed) / (365 days * RATE_PRECISION);
            market.supplyBalance[user] += interest;
        }
        
        if (market.borrowBalance[user] > 0) {
            uint256 interest = (market.borrowBalance[user] * market.borrowRate * timeElapsed) / (365 days * RATE_PRECISION);
            market.borrowBalance[user] += interest;
        }
        
        market.lastUpdate[user] = block.timestamp;
    }
    
    function supply(address token) external payable {
        require(supportedTokens[token], "Token not supported");
        require(msg.value > 0, "Amount must be greater than 0");
        
        updateInterest(token, msg.sender);
        
        Market storage market = markets[token];
        market.supplyBalance[msg.sender] += msg.value;
        market.totalSupply += msg.value;
        
        emit Supplied(msg.sender, token, msg.value);
    }
    
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
    
    function borrow(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        
        updateInterest(token, msg.sender);
        
        // Check collateral
        uint256 collateralValue = getAccountCollateralValue(msg.sender);
        uint256 borrowValue = getAccountBorrowValue(msg.sender) + (amount * tokenPrices[token]) / PRICE_PRECISION;
        
        require(borrowValue * 10000 <= collateralValue * markets[token].collateralFactor, "Insufficient collateral");
        
        Market storage market = markets[token];
        market.borrowBalance[msg.sender] += amount;
        market.totalBorrow += amount;
        
        payable(msg.sender).transfer(amount);
        
        emit Borrowed(msg.sender, token, amount);
    }
    
    function repay(address token) external payable {
        require(supportedTokens[token], "Token not supported");
        
        updateInterest(token, msg.sender);
        
        Market storage market = markets[token];
        uint256 borrowBalance = market.borrowBalance[msg.sender];
        uint256 repayAmount = msg.value > borrowBalance ? borrowBalance : msg.value;
        
        market.borrowBalance[msg.sender] -= repayAmount;
        market.totalBorrow -= repayAmount;
        
        // Refund excess payment
        if (msg.value > repayAmount) {
            payable(msg.sender).transfer(msg.value - repayAmount);
        }
        
        emit Repaid(msg.sender, token, repayAmount);
    }
    
    function getAccountCollateralValue(address user) public view returns (uint256) {
        uint256 totalValue = 0;
        
        // Only checking ETH for simplicity
        Market storage market = markets[address(0)];
        totalValue += (market.supplyBalance[user] * tokenPrices[address(0)]) / PRICE_PRECISION;
        
        return totalValue;
    }
    
    function getAccountBorrowValue(address user) public view returns (uint256) {
        uint256 totalValue = 0;
        
        // Only checking ETH for simplicity
        Market storage market = markets[address(0)];
        totalValue += (market.borrowBalance[user] * tokenPrices[address(0)]) / PRICE_PRECISION;
        
        return totalValue;
    }
    
    function getAccountInfo(address user) external view returns (uint256 supplyBalance, uint256 borrowBalance, uint256 collateralValue, uint256 borrowValue) {
        Market storage market = markets[address(0)];
        return (
            market.supplyBalance[user],
            market.borrowBalance[user],
            getAccountCollateralValue(user),
            getAccountBorrowValue(user)
        );
    }
    
    function updateTokenPrice(address token, uint256 price) external onlyOwner {
        tokenPrices[token] = price;
    }
}
