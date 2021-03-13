pragma solidity >=0.6.0 <0.7.0;

import "./LedgerLib.sol";

/// @title A Phoenix vault to protect your money against address theft
/** @notice 
    Every request to move money out of Phoenix is done via a Tier2 account, then has to wait
    a certain delay. During that delay, Tier1 user can cancel the transfer.
    Security is achieved through the lack of incentives for thieves, and the rare usage of the 
    Tier1 password.
    For detailed explanation, see...
    */
/// @author Uri Kirstein
/// @dev Version 0.1.0
contract Phoenix {
    enum Role {None, Tier1, Tier2}
    mapping(address => Role) privileges;

    //Library used to store and manage transaction requests
    LedgerLib.Ledger internal ledger;
    
    // uint constant MIN_DELAY = 6*60; // An hour
    uint constant MIN_DELAY = 4; // For shortness of testing
    uint constant MAX_DELAY = 2 ** 32;

    //events
    event Deposit(uint amount);
    event Request(uint indexed id, address to, uint amount, address indexed from);
    event Withdrawal(uint indexed id, address to, uint amount);
    event Cancellation(uint indexed id, uint amount);
    event Reset();  //All transaction requests were deleted
    event Lock(uint unlocked_at);   //Block number at which the lock is opened
    event Fired(address former_tier_two, uint number_of_deleted_transactions);
   

    /// @notice initializes this Phoenix
    /// @param tier1 A tier 1 user address. Cannot be deleted later!
    /// @param tier2 A tier 2 user address. Can be deleted later
    /// @param delay Amount of blocks that must pass between transaction requests and withdrawals
    /// @param maxNumTransactions Maximal number of transaction records
    constructor(address tier1,
        address tier2,
        uint delay, 
        uint maxNumTransactions
        ) 
        public {
            require(maxNumTransactions > 0, "Must allow at least one transaction");
            
            require(delay >= MIN_DELAY, "delay is smaller than the minimum allowed");
            require(delay <= MAX_DELAY, "delay must be smaller than the maximal delay allowed");
            require(tier1!=tier2, "an address cannot be both tier1 and tier2");
            require(tier1!=msg.sender, 
                "Tier 1 address must be different than the adress used to constuct Phoenix");

            LedgerLib.initLedger(ledger, maxNumTransactions, delay);

            privileges[tier1] = Role.Tier1;
            privileges[tier2] = Role.Tier2;
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////
    /////////Fallback//////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Fallback function.
    fallback () external payable {
        emit Deposit(msg.value);
    }

    /// @notice Receive function. Send money to this contract
    receive() external payable {
        emit Deposit(msg.value);
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////
    /////////Destructor////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice destructor. Reverts if Phoenix is not empty
    function destroy() public onlyTierOne whenUnlocked {
        address tmp_address = address(this);
        uint my_balance = tmp_address.balance;
        require (my_balance == 0, "Vault can only be destroyed when it is empty");
        address payable recipient = msg.sender; //Should be 0 money anyway
        selfdestruct(recipient);
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////
    /////////Access control modifiers//////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////

	modifier onlyTierOne {
        require(privileges[msg.sender] == Role.Tier1, 
            "Only a tier one address can call this function");
		_;
	}

    modifier onlyTierTwo {
        require(privileges[msg.sender] == Role.Tier2, 
            "Only a tier two address can call this function");
		_;
	}

    modifier anyTier {
        require(privileges[msg.sender] != Role.None, 
            "Only a tier one or two address can call this function");
		_;
	}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    ///////Timed lock//////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///Block number in which the lock will be opened. Can only increase
    uint public lock_timeout = 0;

    /// @notice Locks Phoenix for n blocks. While Phoenix is locked, money cannot be withdrawn
    /// @dev used to contain a Tier1 address breach
    /// @param n_blocks The number of blocks for which you desire to lock Phoenix
    function lock (uint n_blocks) public onlyTierOne {
        uint open_time = block.number + n_blocks;
        require(open_time > lock_timeout, "Vault is already locked during the requested time");
        lock_timeout = open_time;
        emit Lock(open_time);
    }

    modifier whenUnlocked {
        require (block.number >= lock_timeout, 
                 "You can only call this function once the lock expires");
        _;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    /////////Tier accounts management//////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Adds a TierOne address. Cannot be deleted
    /// @dev no known use case uses this.
    /// @param candidate A new TierOne address. Cannot be an existing address of any tier address(0).
    function addTierOne (address candidate) public onlyTierOne whenUnlocked {
        Role prev_role = privileges[candidate];
        require(prev_role != Role.Tier1, "candidate is already a tier 1 address");
        require(prev_role != Role.Tier2, "candidate is already a tier 2 address");
        privileges[candidate] = Role.Tier1;
    }

    /// @notice Adds a TierTwo address.
    /// @param candidate A new TierTwo address. Cannot be an existing address of any tier or address(0).
    function addTierTwo (address candidate) public onlyTierOne whenUnlocked {
        Role prev_role = privileges[candidate];
        require(prev_role != Role.Tier1, "candidate is already a tier 1 address");
        require(prev_role != Role.Tier2, "candidate is already a tier 2 address");
        privileges[candidate] = Role.Tier2;
    }

    /** @notice removes a Tier2 address if found, and all transactions initiated by it. 
                Reverts if address is not found 
    */
    /// @dev it can be readded later
    /// @param candidate The tier2 address we wish to remove.
    function removeTierTwo (address candidate) public onlyTierOne whenUnlocked {
        require(privileges[candidate] == Role.Tier2, 
            "address is not a tier two address of this Phoenix");

        privileges[candidate] = Role.None;
        
        uint num_deletions = LedgerLib.cancelAllByInitiator(ledger, candidate);
        emit Fired(candidate, num_deletions);
    }
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    /////////Ledger////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /** @notice Adds a new transaction request. Reverts if: 
                * There is not enough money in Phoenix
                * There is not enough in Phoenix to pay all previous requests plus this one
                * The ledger is full
                Emits Request event if succesful
    */
    /// @param recipient To address to which we want to send the money
    /// @param amount how much money to send, in wei
    function addTransaction(address payable recipient, uint amount) public onlyTierTwo whenUnlocked{
        address my_address = address(this);
        require(recipient != my_address, " cannot send money to itself");
        require(recipient != address(0), "Money sent to address zero will be lost forever");
        uint my_balance = my_address.balance;
        require(amount + ledger.total_commitments <= my_balance, 
            "This amount cannot be payed due to previous requests, or due to insufficient funds");
        require(amount + ledger.total_commitments > ledger.total_commitments, 
            "amount would create an overflow in the total ledger commitments");
        address sender = msg.sender;
        (bool success, uint id) = LedgerLib.addRequest(ledger, recipient, amount, sender);
        require(success, "addition failed because the ledger of Phoenix is full");
        emit Request(id, recipient, amount, sender);
    }


    /** @notice Executes a transaction request. Reverts if: 
                * transaction not found
                * not enough time has passed since the request of this transaction
                * There is not enough money in Phoenix (should never happen)
                Emits Withdrawal event if succesful
    */
    /// @param transaction_id the unique identifier of the transaction record we want to execute
    function withdraw(uint transaction_id) public whenUnlocked {
        (uint success, uint withdraw_amount, address payable recipient) = 
            LedgerLib.commitPayment(ledger, transaction_id);
        require (success != 1, "transaction not found");
        require(success != 2, "transaction not old enough to withdraw");
        recipient.transfer(withdraw_amount);
        emit Withdrawal(transaction_id, recipient, withdraw_amount);
	}

    /// DELETION FUNCTIONS

    /// @notice clears all payments from Phoenix's records. Emits Reset event
    function clearAllPayments() public onlyTierOne {
        LedgerLib.clearAllPayments(ledger);
        emit Reset();
    }
    

    /** @notice Deletes a transaction request with a given ID from Phoenix's records. Reverts if
                not found. Emits Cancellation event if successful
    */
    /// @param id a unique identifier of the transaction record we wish to cancel. 0 is invalid
    function cancelTransactionById(uint id) public onlyTierOne {
        uint amount = LedgerLib.cancelTransactionById(ledger, id);
        require(amount != 0, "transaction not found");
        emit Cancellation(id, amount);
    }

    /** @notice Deletes a transaction request with a given ID from Phoenix's records, if it was 
                initiated with the same tierOne address as the sender of this transaction. Reverts 
                if not found or was initiated by a different address.
                Emit cancellation event if successful
    */
    /// @param id a unique identifier of the transaction record we wish to cancel
    function cancelMyTransaction(uint id) public onlyTierTwo() {
        (int res, uint amount) = LedgerLib.cancelTransactionIfInitiator(ledger, id, msg.sender);
        require(res != 1, "transaction not found");
        require(res != 2, "transaction initiated by someone else");
        emit Cancellation(id, amount);
    }

}

