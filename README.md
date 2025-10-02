# Web3 Arbitrum 14-Day Bootcamp: Time-Locked Safe, Smart Will, and Account Abstraction with ERC-4337

![Build Status](https://github.com/lezlei/web3-arbitrum-14-day-bootcamp/actions/workflows/test.yml/badge.svg)

A repository documenting a 14-day personal challenge to learn Web3 development from scratch and deploy 3 dApps on the Arbitrum testnet, 3rd AA-implemented dApp repo is: (https://github.com/lezlei/aa-smart-will)

## The Challenge

Inspired by the upcoming TOKEN2049 event, I set a personal goal: to go from zero to a deployed dApp on Arbitrum in 14 days. After managing to get my 1st dApp deployed on the Arbitrum testnet in 3 days, I decided to build and deploy a more complex dApp in the remaining time. 

Drawing inspiration from a past internship at a law firm, where I witnessed firsthand the drawbacks of traditional wills and estate planning, such as expensive law fees and issues with executors of wills (especially when joint-executors are named who don't see eye to eye after the passing of the testator), I decided to build the V1 of a Smart Will that can be improved in the future with the help of off-chain tools such as Chainlink bots and Oracles.

After completing V1 of the Smart Will in on Day 6, I learned about Account Abstraction (AA) and ERC-4337 and how it's a game-changer for UX, so I decided to build an AA-implemented Smart Will

---

## Project 1: Time-Locked Safe (Completed: Day 1-3) src/safe/TimeLockedSafe.sol

A decentralized, multi-user contract that allows anyone to lock a specific amount of ETH for a self-defined period. The funds can only be withdrawn by the original depositor after their lock time has expired.

### Deployed on Arbitrum Sepolia

- **Contract Address:** `0xb724Ba4BC9bCb6935BCb518Eac35f5fb7096ECE8`
- **[View on Arbiscan](https://sepolia.arbiscan.io/address/0xb724ba4bc9bcb6935bcb518eac35f5fb7096ece8)**

### Core Functions

- `deposit(uint256 _lockDuration)`: Locks `msg.value` amount of ETH for the `msg.sender` for a specified number of seconds.
- `withdraw()`: Allows the `msg.sender` to retrieve their locked funds after the `unlockTime` has passed.

---

## Project 2: Smart Will (In Progress: Day 4-14) src/will/Will.sol
- **Contract Address:** `0x06E42DC0509a20DC40090262E1d3952906E5018d`
- **[View on Arbican](https://sepolia.arbiscan.io/address/0x06e42dc0509a20dc40090262e1d3952906e5018d)**

Building on the concepts from the Time-locked Safe, the Smart Will is a more advanced contract that acts as a decentralized "dead man's switch." It allows a user to designate a beneficiary who can claim their locked funds after a specified period of user inactivity.

---

## Tech Stack

- **Smart Contracts:** Solidity
- **Testing & Deployment:** Foundry
- **Network:** Arbitrum Sepolia

## Local Setup

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/lezlei/web3-arbitrum-14-day-bootcamp.git](https://github.com/lezlei/web3-arbitrum-14-day-bootcamp.git)
    cd web3-arbitrum-14-day-bootcamp
    ```
2.  **Install dependencies:**
    ```bash
    forge install
    ```
3.  **Run tests:**
    ```bash
    forge test
    ```