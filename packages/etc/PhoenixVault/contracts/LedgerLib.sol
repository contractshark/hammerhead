pragma solidity >=0.6.0 <0.7.0;

/// @title A ledger data structure for phoenix
/** @notice This ledger keeps previous transaction requests, which can
    either be withdrawn after a certain amount of blocks have passed, or canceled. */
/// @author Uri Kirstein
/// @dev Phoenix is responsible for access control and funds control.

library LedgerLib {
    uint constant NULL = 0;

    ///@notice A single money transfer request record from Phoenix
    struct Request {
        address initiator;          //The Tier 2 user address that initiated this transaction
        address payable recipient;  //The address to which the money will be sent
        uint amount;                //How much money to transfer, in wei
        uint block_created;         //Block number in creation. Used as a time stamp
        uint ID;                    //A unique identifier of the transaction
        uint next;               // The next record in chronological order
        uint prev;               // The previous record in chronological order
    }


    /// @notice The data structure that keeps transaction requests
    struct Ledger {
        mapping(uint => Request) records;
        uint delay;              //How many blocks need to pass between request and withdrawal
        uint total_commitments;  //Total value of all requests in wei. Prevents overbooking
        uint length;             //Number of transactions in the ledger
        uint capacity;           //Max # of records
        uint nonce;              //Used for transaction ID generation
        uint last_erasure_id;    //Ids smaller than this number will be ignored
        uint newest;             //id of newest record, head of the list
    }


     /// @notice Initializes the data structure.
     /// @dev Called from Phoenix's constructor
     /// @param self address of the LedgerLib instance
     /// @param capacity maximal number of transaction records in storage, positive
     /** @param delay minimal amount of blocks that must pass between transaction request and
                     withdrawal. Must be positive*/
    function initLedger (Ledger storage self, uint capacity, uint delay) public {

        require(delay > 0, "The number of blocks for the delay must be positive");
        require(capacity > 0, "capacity must be positive");

        self.delay = delay;
        self.capacity = capacity;
        self.nonce = 1;

        /*
        All fields below will get value equal to byte code zero:

        self.total_commitments = 0;
        self.length = 0;
        self.newest = NULL;
        self.last_erasure_id = 0;
        */
    }

    /// @notice Adds a new transaction record. reverts if amount is zero, or if the ledger is full
    /// @param self address of the LedgerLib instance
    /// @param recipient address to which the money will be transfered
    /// @param amount how much money to transfer in wei, must be positive
    /// @param sender address of the requester. Used for deletion identification
    /// @return added - true if a new record was added, false otherwise (Phoenix was full)
    /// @return id - given transaction ID number, irrelevant if added is false
    /// @dev Vault/User must check that phoenix.balance > this.total_commitments + amount
    function addRequest (
        Ledger storage self,
        address payable recipient,
        uint amount,
        address sender)
        public returns (bool added, uint id) {

        require(amount > 0, "amount is zero");  // Nothing to pay

        if (self.length >= self.capacity) return (false, 0); //Ledger is full. Will be equal

        // Create new transaction object
        Request memory new_tran;
        new_tran.amount = amount;
        new_tran.initiator = sender;
        new_tran.recipient = recipient;
        new_tran.block_created = block.number;
        new_tran.ID = self.nonce;
        new_tran.prev = self.newest;

        // Below line happens for free
        // new_tran.next = NULL;

        //Add transaction to records
        if (self.newest != NULL) {
            self.records[self.newest].next = new_tran.ID;
        }
        self.newest = new_tran.ID;

        self.records[new_tran.ID] = new_tran;

        //update state
        self.total_commitments += amount;
        self.length++;
        self.nonce++;

        return (true, new_tran.ID);
    }


    /// @notice Empties the records
    /// @param self - address of the LedgerLib instance
    function clearAllPayments(Ledger storage self) public {
        self.length = 0;
        self.total_commitments = 0;
        self.newest = NULL;
        self.last_erasure_id = self.nonce;
    }


    /** @notice removes a transaction with a given id from records, even if it is not ready for
        withdrawal */
    /// @param self address of the LedgerLib instance
    /// @param id the unique identifier of the transaction you want to cancel
    /// @return amount - the wei value of the deleted transaction. 0 if ID not found
    function cancelTransactionById(Ledger storage self, uint id) public returns (uint amount) {
        return deleteTransactionById(self, id);
    }


    /** @notice removes a transaction with a given id from records, even if it is not ready for
        withdrawal but only if given address is the transaction's initiator's address */
    /// @dev Vault must pass the correct address
    /// @param self address of the LedgerLib instance
    /// @param id the unique identifier of the transaction you want to cancel
    /// @param initiator the address of the transaction's initiator
    /// @return result 0 if succeeded, 1 if ID not found, 2 if wrong initiator address
    /// @return amount - the wei value of the deleted transaction. 0 if ID not found
    function cancelTransactionIfInitiator(
        Ledger storage self,
        uint id,
        address initiator
        )
        public returns (int result, uint amount){
            if (self.records[id].ID == NULL) return (1, 0);
            if (self.records[id].initiator != initiator) return (2, 0);
            uint _amount = deleteTransactionById(self, id);
            if (_amount == 0)
                return (1, _amount);
            return (0, _amount);
    }


    /// @notice Removes a transaction by a given id if it is old enough to be withdrawn
    /// @dev this will remove the transaction from the records, but Phoenix has to transfer money
    /// @param self address of the LedgerLib instance
    /// @param id the unique identifier of the transaction you want to cancel
    /// @return result - 0 is success, 1 transaction not found, 2 transaction not old enough
    /// @return amount - the wei value of the deleted transaction. 0 if ID not found
    /// @return recipient - the recieving address of the deleted transaction. 0 if ID not found
    function commitPayment(Ledger storage self, uint id) public returns (
        uint result,
        uint amount,
        address payable recipient) {
            if (self.records[id].ID == NULL) return (1, 0, address(0));
            if (self.records[id].block_created + self.delay > block.number)
                return (2, 0, address(0));
            address _recipient = self.records[id].recipient;
            uint _amount = deleteTransactionById(self, id);
            if (_amount == 0)
                return (1, _amount, payable(_recipient));
            return (0, _amount, payable(_recipient));
        }


    /// @notice removes all transactions that were initiated with the given address, ignoring age
    /// @dev used by Tier1 when Tier2 is stolen
    /// @param self address of the LedgerLib instance
    /// @param initiator the address of the initiator you want to delete the records of
    /// @return num_deletions the number of transactions deleted
    function cancelAllByInitiator(Ledger storage self, address initiator) public
        returns (uint num_deletions) {
        uint result = 0;
        uint curr_id = self.newest;
        while (curr_id != NULL) {
            uint prev_id = self.records[curr_id].prev;
            if (self.records[curr_id].initiator == initiator){
                deleteTransactionById(self, curr_id);
                result++;
            }
            curr_id = prev_id;
        }
        return result;
    }

///////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////Internal functions/////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////


       /** @notice removes a transaction with a given id from records, ignoring all conditions:
        - even if it is not old enough for withdrawal
        - ignores initiator
        */
    /// @param id the unique identifier of the transaction you want to cancel
    /// @return amount - the wei value of the deleted transaction. 0 if ID not found
    function deleteTransactionById(Ledger storage self, uint id) internal returns (uint amount) {
        if (id < self.last_erasure_id || id == NULL || id >= self.nonce) return 0;
        Request memory candidate = self.records[id];

        uint result = candidate.amount;
        uint next_node_id = candidate.next;
        uint prev_node_id = candidate.prev;
        bool next_exists = next_node_id != NULL;
        bool prev_exists = prev_node_id != NULL;

        if (next_exists && prev_exists) {
            self.records[next_node_id].prev = prev_node_id;
            self.records[prev_node_id].next = next_node_id;
        } else if (next_exists) { // We removed the oldest node
            self.records[next_node_id].prev = NULL;
        } else if (prev_exists) { // We remove the newest node
            assert(self.newest == id);  // Remove this when verification is successful
            self.records[prev_node_id].next = NULL;
            self.newest = prev_node_id;
        } else {  // We removed the only node
            assert(self.newest == id);  // Remove this when verification is successful
            self.newest = NULL;
        }

        self.length--;
        self.total_commitments -= candidate.amount;

        delete self.records[id];

        return result;
    }

}

