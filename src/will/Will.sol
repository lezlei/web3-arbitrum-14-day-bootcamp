// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract SmartWill {
    // Variables
    mapping(address => Will) wills;

    struct Will {
        uint256 lastPing; // The timestamp of the last "I'm alive" signal
        uint256 timeout; // Length of time after lastPing for beneficiaries to be able to claim
        uint256 usableFunds; // Deposited funds that have not been designated
        mapping(address => uint256) beneficiaries; // Mapping of beneficiary addresses to their inheritance amount
        address[] beneficiaryList; // List of beneficiaries
    }

    // Errors
    error WillAlreadyExists(address owner);
    error WillNotFound(address owner);
    error InsufficientFunds(uint256 required, uint256 available);
    error BeneficiaryExists(address beneficiary);
    error BeneficiaryNotFound(address beneficiary);
    error TimeoutNotExpired(uint256 unlockTime);
    error CallerNotBeneficiary(address caller);
    error NothingToClaim();
    error NoValueSent();
    error ZeroDuration();
    error UnviableAmount();
    error RemoveBeneficiaryInstead();

    // --- Events ---
    event WillCreated(address indexed owner, uint256 timeout);
    event Deposit(address indexed owner, uint256 amount);
    event Withdrawal(address indexed owner, uint256 amount);
    event Ping(address indexed owner);
    event BeneficiaryAdded(address indexed owner, address indexed beneficiary, uint256 amount);
    event BeneficiaryUpdated(address indexed owner, address indexed beneficiary, uint256 newAmount);
    event BeneficiaryRemoved(address indexed owner, address indexed beneficiary);
    event InheritanceClaimed(address indexed owner, address indexed beneficiary);

    // Functions
    // Creates a will
    function createWill(uint _timeoutInDays) public {
        if (wills[msg.sender].lastPing > 0) {
            revert WillAlreadyExists(msg.sender);
        }

        Will storage userWill = wills[msg.sender];
        userWill.lastPing = block.timestamp;
        userWill.timeout = _timeoutInDays * 1 days;
        emit WillCreated(msg.sender, _timeoutInDays * 1 days);
    }

    // Allows beneficiaries to claim inheritance
    function claimInheritance(address _owner) public {
        if (wills[_owner].lastPing == 0) {
            revert WillNotFound(_owner);
        }
        if (wills[_owner].beneficiaries[msg.sender] == 0) {
            revert NothingToClaim();
        }
        if (block.timestamp < wills[_owner].lastPing + wills[_owner].timeout) {
            revert TimeoutNotExpired(wills[_owner].lastPing + wills[_owner].timeout);
        }
        (bool success,) = msg.sender.call{value: wills[_owner].beneficiaries[msg.sender]}("");
        require(success, "ETH transfer failed");
        wills[_owner].beneficiaries[msg.sender] = 0;
        emit InheritanceClaimed(_owner, msg.sender);
    }

    // Updates lastPing time to current time
    function ping() public {
        if (wills[msg.sender].lastPing == 0) {
            revert WillNotFound(msg.sender);
        }
        wills[msg.sender].lastPing = block.timestamp;
        emit Ping(msg.sender);
    }

    // Returns all the info of the user's will
    function getWillDetails() public view returns (uint256 _usable, address[] memory _beneficiaries) {
        if (wills[msg.sender].lastPing == 0) {
            revert WillNotFound(msg.sender);
        }
        _usable = wills[msg.sender].usableFunds;
        _beneficiaries = wills[msg.sender].beneficiaryList;
    }

    // Deposits funds into user's usable_Funds
    function deposit() public payable {
        if (msg.value == 0) {
            revert NoValueSent();
        }
        if (wills[msg.sender].lastPing == 0) {
            revert WillNotFound(msg.sender);
        }

        wills[msg.sender].usableFunds += msg.value;
        wills[msg.sender].lastPing = block.timestamp;
        emit Deposit(msg.sender, msg.value);
    }

    // Allows user to withdraw funds from usable_Funds
    function withdraw(uint256 _amount) public {
        if (_amount <= 0) {
            revert NoValueSent();
        }
        if (wills[msg.sender].lastPing == 0) {
            revert WillNotFound(msg.sender);
        }
        if (_amount > wills[msg.sender].usableFunds) {
            revert InsufficientFunds(_amount, wills[msg.sender].usableFunds);
        }

        (bool success,) = msg.sender.call{value: _amount}("");
        require(success, "ETH transfer failed");
        wills[msg.sender].usableFunds -= _amount;
        wills[msg.sender].lastPing = block.timestamp;
        emit Withdrawal(msg.sender, _amount);
    }

    // Creates a beneficiary and designates them an amount of inheritance
    function addBeneficiary(address _beneficiary, uint256 _amount) public {
        if (wills[msg.sender].lastPing == 0) {
            revert WillNotFound(msg.sender);
        }
        if (wills[msg.sender].beneficiaries[_beneficiary] > 0) {
            revert BeneficiaryExists(_beneficiary);
        }
        if (_amount > wills[msg.sender].usableFunds) {
            revert InsufficientFunds(_amount, wills[msg.sender].usableFunds);
        }
        if (_amount < 0) {
            revert UnviableAmount();
        }

        wills[msg.sender].beneficiaries[_beneficiary] = _amount;
        wills[msg.sender].usableFunds -= _amount;
        wills[msg.sender].beneficiaryList.push(_beneficiary);
        wills[msg.sender].lastPing = block.timestamp;
        emit BeneficiaryAdded(msg.sender, _beneficiary, _amount);
    }

    // Updates the amount of inheritance designated to a beneficiary
    function updateBeneficiary(address _beneficiary, uint256 _amount) public {
        if (wills[msg.sender].lastPing == 0) {
            revert WillNotFound(msg.sender);
        }
        if (_amount - wills[msg.sender].beneficiaries[_beneficiary] > wills[msg.sender].usableFunds) {
            revert InsufficientFunds(_amount, wills[msg.sender].usableFunds);
        }
        if (_amount <= 0) {
            revert RemoveBeneficiaryInstead();
        }

        // Update usable funds
        if (_amount > wills[msg.sender].beneficiaries[_beneficiary]) {
            wills[msg.sender].usableFunds -= (_amount - wills[msg.sender].beneficiaries[_beneficiary]);
        }
        if (_amount < wills[msg.sender].beneficiaries[_beneficiary]) {
            wills[msg.sender].usableFunds += (wills[msg.sender].beneficiaries[_beneficiary] - _amount);
        }
        // Update inheritance
        wills[msg.sender].beneficiaries[_beneficiary] = _amount;
        wills[msg.sender].lastPing = block.timestamp;
        emit BeneficiaryUpdated(msg.sender, _beneficiary, _amount);
    }

    // Removes a beneficiary, sending their designated inheritance back to user's usable_Funds
    function removeBeneficiary(address _beneficiary) public {
        if (wills[msg.sender].lastPing == 0) {
            revert WillNotFound(msg.sender);
        }
        if (wills[msg.sender].beneficiaries[_beneficiary] == 0) {
            revert BeneficiaryNotFound(_beneficiary);
        }

        wills[msg.sender].usableFunds += wills[msg.sender].beneficiaries[_beneficiary];
        wills[msg.sender].beneficiaries[_beneficiary] = 0;
        for (uint256 i = 0; i < wills[msg.sender].beneficiaryList.length; i++) {
            if (wills[msg.sender].beneficiaryList[i] == _beneficiary) {
                wills[msg.sender].beneficiaryList[i] = wills[msg.sender].beneficiaryList[wills[msg.sender].beneficiaryList.length - 1];
                wills[msg.sender].beneficiaryList.pop();
                break;
            }
        }
        wills[msg.sender].lastPing = block.timestamp;
        emit BeneficiaryRemoved(msg.sender, _beneficiary);
    }

    /**
     * @notice A simple getter to return the core non-complex data of a will.
     * @dev This is needed because the default public getter is not generated
     * for structs that contain mappings or dynamic arrays.
     */
    function getWillSimpleDetails() public view returns (uint256 lastPing, uint256 timeout, uint256 usableFunds)
    {
        Will storage userWill = wills[msg.sender];
        return (userWill.lastPing, userWill.timeout, userWill.usableFunds);
    }
    
    /**
     * @notice A getter to return the amount for a specific beneficiary of a will.
     */
    function getBeneficiaryAmount(address _beneficiary) public view returns (uint256)
    {
        return wills[msg.sender].beneficiaries[_beneficiary];
    }
}
