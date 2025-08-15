
# 💰 Lending Protocol – ETH-Only Demo

A Solidity-based **lending and borrowing smart contract** where users can supply ETH to earn interest, borrow ETH against their collateral, and have all balances automatically accrue interest over time.
This demo version supports **ETH-only markets** with a mock on-chain price feed.

---

## 📌 Overview

* **Supply ETH** → Earn interest at a fixed APY.
* **Borrow ETH** → Use supplied ETH as collateral.
* **Collateral Factor** → Borrow up to 75% of your collateral value.
* **Interest Accrual** → Simple APY-based calculation for supply and borrow positions.
* **Mock Price Feed** → On-chain prices stored in `tokenPrices`.

**Deployed & Verified Contract:**
`0x153982057Bb2De6caAf4188bf2078f17297354Ed`

---

## ⚙️ Key Features

* **Configurable Interest Rates:** Set per market (`supplyRate`, `borrowRate`).
* **Collateral Enforcement:** Prevents over-borrowing based on collateral value and `collateralFactor`.
* **Price Feed Mapping:** Stores and updates mock USD prices for supported tokens.
* **Event Logging:**

  * `Supplied` – User supplied ETH.
  * `Borrowed` – User borrowed ETH.
  * `Repaid` – Borrow position repaid (fully or partially).
  * `Withdrawn` – Collateral withdrawn.

---

## 🛠 Deployment

**Default ETH Market Settings (`address(0)`):**

* Price: `$2000` USD
* Collateral Factor: **75%**
* Supply Rate: **2% APY**
* Borrow Rate: **5% APY**

**Example Deployment:**

```solidity
LendingProtocol lending = new LendingProtocol();
```

---

## 📜 Core Functions

### **supply(address token)** (payable)

Supply ETH to the protocol and start earning interest.

* **Requires:** `msg.value > 0`
* **Emits:** `Supplied`

---

### **withdraw(address token, uint256 amount)**

Withdraw ETH you’ve supplied.

* **Requires:** Enough supply balance
* **Emits:** `Withdrawn`

---

### **borrow(address token, uint256 amount)**

Borrow ETH against your supplied collateral.

* **Requires:** Borrow value ≤ (collateral value × collateral factor)
* **Emits:** `Borrowed`

---

### **repay(address token)** (payable)

Repay borrowed ETH.

* Excess ETH sent is refunded
* **Emits:** `Repaid`

---

### **getAccountCollateralValue(address user)**

Returns the USD value of a user’s supplied ETH.

---

### **getAccountInfo(address user)**

Returns:
`(supplyBalance, borrowBalance, collateralValue, borrowValue)`

---

### **updateTokenPrice(address token, uint256 price)** (onlyOwner)

Updates the mock USD price for a supported token.

---

## 🧮 Collateral Rule

Borrowing is allowed if:

```
borrowValue * 10000 <= collateralValue * collateralFactor
```

---

## 🧪 Suggested Tests

* User supplies ETH and accrues interest.
* User borrows ETH without exceeding collateral limit.
* Interest accrual over time for both supply and borrow balances.
* Borrow limit enforcement.
* Repay with excess refund.
* Withdraw after repaying loans.

---

## 📄 License

MIT License – Free to use and modify.

---
