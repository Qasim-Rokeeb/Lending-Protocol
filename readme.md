
# 💰 Lending Protocol (ETH-Only Demo)

A Solidity-based **lending and borrowing protocol** supporting ETH as collateral and loan asset, with simple interest accrual, collateral factor limits, and on-chain price feeds (mock).

---

## 📌 Overview

* **Supply ETH** to earn interest.
* **Borrow ETH** against supplied collateral.
* **Interest Accrual:** Simple APY for supply and borrow positions.
* **Collateral Factor:** Limits borrow capacity to a percentage of supplied collateral (default: 75%).
* **On-chain Price Feed (Mock):** Used for collateral and borrow value calculation.

**Deployed & Verified:**
`0x153982057Bb2De6caAf4188bf2078f17297354Ed`


---

## ⚙️ Key Features

* **Interest Rates:** Configurable per market (`supplyRate`, `borrowRate`).
* **Collateral Enforcement:** Borrow limit calculated using `collateralFactor`.
* **Price Feeds:** Maintains `tokenPrices` mapping.
* **Events:**

  * `Supplied`
  * `Borrowed`
  * `Repaid`
  * `Withdrawn`

---

## 🛠 Deployment

### Defaults on Deployment:

* ETH market (`address(0)`) initialized with:

  * Price: `$2000`
  * Collateral factor: `75%`
  * Supply rate: `2% APY`
  * Borrow rate: `5% APY`

### Example:

```solidity
LendingProtocol lending = new LendingProtocol();
```

---

## 📜 Functions

### **supply(address token)** (payable)

Supply ETH to the protocol to earn interest.

* **Requires:** `msg.value > 0`.
* **Emits:** `Supplied`.

---

### **withdraw(address token, uint256 amount)**

Withdraw supplied ETH.

* **Requires:** Sufficient supply balance.
* **Emits:** `Withdrawn`.

---

### **borrow(address token, uint256 amount)**

Borrow ETH using supplied collateral.

* **Requires:** Borrow limit not exceeded (based on `collateralFactor` and prices).
* **Emits:** `Borrowed`.

---

### **repay(address token)** (payable)

Repay borrowed ETH.

* **Refunds:** Excess ETH sent.
* **Emits:** `Repaid`.

---

### **getAccountCollateralValue(address user)**

Returns total USD value of supplied assets.

---

### **getAccountBorrowValue(address user)**

Returns total USD value of borrowed assets.

---

### **getAccountInfo(address user)**

Returns `(supplyBalance, borrowBalance, collateralValue, borrowValue)` for a user.

---

### **updateTokenPrice(address token, uint256 price)** (onlyOwner)

Updates the price feed for a token.

---

## 🧮 Collateral Math

Borrow allowed if:

```
borrowValue * 10000 <= collateralValue * collateralFactor
```

---

## 📄 License

MIT License – Free to use and modify.

---
