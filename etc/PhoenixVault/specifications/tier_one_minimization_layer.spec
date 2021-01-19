pragma specify 0.1

methods {
    getBalance() returns uint envfree
    getTotalCommitments() returns uint envfree
    getTotalLedgerCommitments() returns uint envfree
    isThereCommitmentOverflow() returns bool envfree
    all_initiators_are_tier_two() returns bool envfree
    node_in_list(uint256) returns bool envfree
    no_transactions_to_illegal_addresses() returns bool envfree
}

/////////////////////////////////////// Property #15 //////////////////////////////////////////////
rule no_overcommitments_or_overflows_cancellations {
    env e;
    require e.msg.sender != 0;
    sinvoke check_rep(e);
    
    method f;

    require (f.name == "cancelMyTransaction" || f.name == "withdraw" || 
             f.name == "cancelTransactionById");
    uint256 id;
    require node_in_list(id);
    sinvoke f(e, id);

    bool final_overflow = sinvoke isThereCommitmentOverflow();
    assert !final_overflow, "overflow never occurs";

    uint final_expected_commitments = sinvoke getTotalCommitments();
    uint final_actual_commitments = sinvoke getTotalLedgerCommitments();
    require (final_expected_commitments == final_actual_commitments);

    uint final_balance = sinvoke getBalance();
    assert final_actual_commitments <= final_balance, 
        "cannot commit to pay more money than Phoenix has";
}

rule no_overcommitments_or_overflows_rest {
    env e;
    require e.msg.sender != 0;
    sinvoke check_rep(e);
    
    method f;

    require (f.name != "cancelMyTransaction" && f.name != "withdraw" && 
             f.name != "cancelTransactionById");
    
    calldataarg arg;
    sinvoke f(e, arg);

    bool final_overflow = sinvoke isThereCommitmentOverflow();
    assert !final_overflow, "overflow never occurs";

    uint final_expected_commitments = sinvoke getTotalCommitments();
    uint final_actual_commitments = sinvoke getTotalLedgerCommitments();
    require (final_expected_commitments == final_actual_commitments);

    uint final_balance = sinvoke getBalance();
    bool name_req = f.name == "cancelMyTransaction" || f.name == "withdraw" 
                    || f.name == "cancelTransactionById";
    assert final_actual_commitments > final_balance => name_req, 
        "cannot commit to pay more money than Phoenix has";
}

/////////////////////////////////////// Property #16 & 17 /////////////////////////////////////////
rule all_transactions_are_to_legal_addresses {
    env e;
    sinvoke check_rep(e);

    address sender = e.msg.sender;
    require (sender != 0);

    method f;
    calldataarg arg;
    sinvoke f(e, arg);

    bool result = sinvoke no_transactions_to_illegal_addresses();
    assert result;
}


/////////////////////////////////////// Property #18 //////////////////////////////////////////////
rule initiators_are_tier2 {
    env e;
    require e.msg.sender != 0;
    sinvoke check_rep(e);

    method f;
    calldataarg arg;
    invoke f(e, arg);

    bool correct_finish = sinvoke all_initiators_are_tier_two();
    assert correct_finish, "all transaction initiators should be tier 2 addresses";
}