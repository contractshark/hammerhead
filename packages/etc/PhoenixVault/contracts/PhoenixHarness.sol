pragma solidity >=0.6.0 <0.7.0;

import "./Phoenix.sol";
import "./LedgerLib.sol";

/// @title A harness file to the Phoenix vault used for specification
/** @notice 
    This is a class that inherits from Vault.sol, and includes an API that reveals internal state
    parameters. This file is used for specification via the Certora prover.
    This file is NOT INTENDED FOR DEPLOYMENT - it is simply a more expensive, and potentially more
    vulnerable version of the Phoenix contract.
*/
/// @author Uri Kirstein
/// @dev Version 0.1.0

contract PhoenixHarness is Phoenix {

    // An init function used as the constructor - can be empty
    constructor(address tier1, address tier2, uint delay, uint maxNumTransactions)
    Phoenix(tier1, tier2, delay, maxNumTransactions)
    public
    {}

    uint constant NULL = 0;

    /*
    Returns the balance of the contract.
    */
    function getBalance() public view returns (uint balance) {
        address my_addr = address(this);
        return my_addr.balance;
    }

    /*
    Used for rule tier_one_users_cannot_be_removed.
    Check if an address is a tier one user in this contract.
    */
    function isTierOneAddress(address suspect) public view returns (bool) {
        return privileges[suspect] == Role.Tier1;
    }

    /*
    Used for rule tier_one_users_cannot_be_removed.
    Check if an address is a tier one user in this contract.
    */
    function isTierTwoAddress(address suspect) public view returns (bool) {
        return privileges[suspect] == Role.Tier2;
    }

    /*
    Returns the number of times a transaction with given id appears in records (should be 0 or 1).
    */
    function countTransaction(uint id) public view returns (uint num_appearances){
        uint curr_id = ledger.newest;
        uint appearances = 0;

        while (curr_id != NULL) {
            if (ledger.records[curr_id].ID == id) {
                appearances++;
            }
            curr_id = ledger.records[curr_id].prev;
        }

        return appearances;
    }

    /*
    Returns true if all transaction ids in ledger are unique, false otherwise.
    */
    function transactionIdsUnique() public view returns (bool unique){
        uint curr_id = ledger.newest;

        while (curr_id != NULL) {
            uint id = ledger.records[curr_id].ID;
            if (countTransaction(id) > 1) {
                return false;
            }
            curr_id = ledger.records[curr_id].prev;
        }

        return true;
    }

    /*
    Gets an id of a transaction,
    Returns:
        - The withdrawal time of the transaction if found AND no overflow
        - 0 if not found OR overflow
        -Overflow: if block_creted+delay are larger than max_int...
    */
    function getTransactionWithdrawBlock(uint id) public view returns (uint block_num) {
        if (ledger.records[id].ID == NULL) {
            return 0;
        }

        uint delay = ledger.delay;
        uint withdraw_block = ledger.records[id].block_created + delay;

        if (withdraw_block < delay) {
            return 0;  // Overflow
        }
        return withdraw_block;
    }

    /*
    Gets a transaction id and returns its initiator's address. If a transaction with that id was
    not found, the zero address will be returned.
    */
    function getTransactionInitiator(uint id) public view returns (address inititator) {
        return ledger.records[id].initiator;
    }

    /*
    Returns the total commitments field of the Phoenix Vault.
    */
    function getTotalCommitments() public view returns (uint total_commitments) {
        return ledger.total_commitments;
    }

    /*
    Checks if the sum of all commitments in ledger is larger than MAXINT. If so, return true.
    False otherwise.
    */
    function isThereCommitmentOverflow() public view returns (bool has_overflow) {
        uint all_commitments = 0;

        uint curr_id = ledger.newest;
        while (curr_id != NULL) {
            uint curr_amount = ledger.records[curr_id].amount;
            if (all_commitments + curr_amount < all_commitments)
                return true;
            all_commitments += curr_amount;
            curr_id = ledger.records[curr_id].prev;
        }

        return false;
    }

    /*
    Sums all commitments the hard way from the ledger.
    We assume there is no overflow in commitments!
    */
    function getTotalLedgerCommitments() public view returns (uint total_commitments) {
        uint all_commitments = 0;

        uint curr_id = ledger.newest;
        while (curr_id != NULL) {
            all_commitments += ledger.records[curr_id].amount;
            curr_id = ledger.records[curr_id].prev;
        }

        return all_commitments;
    }

    /*
    Returns the length of the linked list of ledger transactions.
    */
    function getRecordsLoad() public view returns (uint256) {
        return ledger.length;
    }

    /*
    Ascertains blocks were created in the past (in network time).
    If not, will revert.
    */
    function no_records_in_the_future() public view {
        uint curr_id = ledger.newest;
        while (curr_id != NULL) {
            assert(ledger.records[curr_id].block_created < block.number);
            curr_id = ledger.records[curr_id].prev;
        }

        // Asserts no overflow that will cause the withdraw block to be in the past.
        assert(ledger.delay + block.number > block.number);
    }

    /*
    Ascertains the transaction's id field can be used by the map to access that transaction.
    If one id of the nodes in the linked list of transactions volates this property, return false.
    Otherise, return true.
    */
    function map_and_linked_list_ids_are_aligned() public view returns (bool valid) {
        if (ledger.records[ledger.newest].ID != ledger.newest)
            return false;

        uint curr_id = ledger.newest;
        while (curr_id != NULL) {
            if (ledger.records[curr_id].ID != curr_id)
                return false;
            curr_id = ledger.records[curr_id].prev;
        }
        return true;
    }

    /*
    Returns the delay field.
    */
    function get_delay() public view returns (uint delay) {
        return ledger.delay;
    }

    /*
    Ascertains the ids of all transactions in the linked list are smaller than the nonce.
    If not, will revert.
    */
    function all_ids_smaller_than_nonce() public view {
        uint curr_id = ledger.newest;
        while (curr_id != NULL) {
            assert (ledger.records[curr_id].ID < ledger.nonce);
            curr_id = ledger.records[curr_id].prev;
        }
    }

    /*
    Ascertains the ids of linked list transactions are greater than last erasure id.
    If not, will revert.
    */
    function all_ids_greater_than_last_erasure_id() public view {
        uint curr_id = ledger.newest;
        while (curr_id != NULL) {
            assert (ledger.records[curr_id].ID >= ledger.last_erasure_id);
            curr_id = ledger.records[curr_id].prev;
        }
    }

    /*
    Ascertains the last erasure id is smaller than the nonce.
    If not, will revert.
    */
    function last_erasure_id_not_greater_than_nonce() public view {
        assert (ledger.last_erasure_id <= ledger.nonce);
    }

    function get_last_erasure_id() public view returns (uint last_erasure_id) {
        return ledger.last_erasure_id;
    }

    function get_length() public view returns (uint length){
        return ledger.length;
    }

    /*
    Returns the actual length of the linked list of transactions.
    */
    function get_list_length() public view returns (uint length) {
        uint _length = 0;
        uint curr_id = ledger.newest;
        while (curr_id != NULL) {
            _length++;
            curr_id = ledger.records[curr_id].prev;
        }
        return _length;
    }

    function head_is_newest_link() public view returns (bool success) {
        return ledger.newest == 0 || ledger.records[ledger.newest].next == 0;
    }

    /*
    Ascertains that there are no deleted nodes in the middle of the linked list of transactions.
    If not, will revert.
    */
    function list_is_continuous() public view {
        uint curr_id = ledger.newest;
        while (curr_id != NULL) {
            assert(ledger.records[curr_id].amount > 0);
            curr_id = ledger.records[curr_id].prev;
        }
    }

    /*
    Returns true if all initiators of all transactions in the ledger are tier two addresses.
    Returns False otherwise.
    */
    function all_initiators_are_tier_two() public view returns (bool success) {
        uint curr_id = ledger.newest;
        while (curr_id != NULL) {
            if(privileges[ledger.records[curr_id].initiator] != Role.Tier2)
                return false;
            curr_id = ledger.records[curr_id].prev;
        }
        return true;
    }

    /*
    Returns true if a node with a given id is in the linked list of transactions, and false 
    otherwise.
    */
    function node_in_list(uint id) public view returns (bool success) {
        uint curr_id = ledger.newest;
        while (curr_id != NULL) {
            if(id == curr_id)
                return true;
            curr_id = ledger.records[curr_id].prev;
        }
        return false;
    }

    function getCapacity() public view returns (uint capacity){
        return ledger.capacity;
    }

    function validate_list_shorter_than_capacity() public view {
        assert(get_length() <= getCapacity());
    }

    /*
    Returns false if there is a transaction in the ledger that send money to the Phoenix Vault 
    itself or to the zero address. True otherwise.
    */
    function no_transactions_to_illegal_addresses() public view returns (bool success) {
        uint curr_id = ledger.newest;
        while (curr_id != NULL) {
            address recipient = ledger.records[curr_id].recipient;
            if (recipient == address(this) || recipient == address(0)){
                return false;
            }
            curr_id = ledger.records[curr_id].prev;
        }
        return true;
    }

    /*
    Validates that all representation invariants we have thought of are kept.
    If not, will revert.
    */
    function check_rep() public view {
        assert(ledger.nonce > 0);
        assert(ledger.nonce + 1 > 0);
        assert(ledger.capacity > 0);

        // Ledger invariants
        assert(transactionIdsUnique());
        assert(!isThereCommitmentOverflow());
        assert(getTotalCommitments() == getTotalLedgerCommitments());
        assert(getTotalLedgerCommitments() <= getBalance());

        // Linked list invariants
        assert(map_and_linked_list_ids_are_aligned());
        assert(get_length() == get_list_length());
        assert(head_is_newest_link());
        
        // Transaction invariants
        assert(all_initiators_are_tier_two());
        assert(no_transactions_to_illegal_addresses());

        /////////////////////////// Not used directly by any property
        // Linked list invariants
        list_is_continuous();
        validate_list_shorter_than_capacity();

        // Nonce related
        all_ids_greater_than_last_erasure_id();
        last_erasure_id_not_greater_than_nonce();
        all_ids_smaller_than_nonce();

        /////////////////////////// Require env
        no_records_in_the_future();
    }
}

