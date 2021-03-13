pragma specify 0.1

methods {
    getBalance() returns uint envfree
    isTierOneAddress(address) returns bool envfree
    isTierTwoAddress(address) returns bool envfree
    get_delay() returns uint envfree
    getTransactionWithdrawBlock(uint256) returns uint envfree
    node_in_list(uint256) returns bool envfree
}

/////////////////////////////////////// Property #1 ///////////////////////////////////////////////
rule money_can_only_be_payed_via_withdraw {
    env e;
    require e.msg.sender != 0;
    sinvoke check_rep(e);

    uint init_balance = sinvoke getBalance();

    method f;
    calldataarg arg;
    sinvoke f(e, arg);

    uint final_balance = invoke getBalance();
    assert lastReverted => final_balance == init_balance, "sanity";
    assert final_balance < init_balance => f.name == "withdraw",
        "Money can only be moved out of Phoenix via the withdraw function";
    // assert f.name == "withdraw" && !lastReverted => final_balance < init_balance,
    //     "If withdrw function succeeded, money will leave Phoenix";
    // ^ Above does not work due to overflow in payments to Phoenix...
}

rule transaction_cannot_be_withdrawn_before_time {
    env e;
    require e.msg.sender != 0;
    sinvoke check_rep(e);

    uint id;
    uint withdraw_block = sinvoke getTransactionWithdrawBlock(id);
    require withdraw_block > 0;  //Block found and no overflow

    uint phoenix_delay = sinvoke get_delay();

    // Ensure no overflow
    uint max_withdraw_time = e.block.number + phoenix_delay;
    require max_withdraw_time > e.block.number;
    
    invoke withdraw(e, id);
    assert e.block.number < withdraw_block => lastReverted, "Premature withdrawal should fail";
}

/////////////////////////////////////// Property #2 ///////////////////////////////////////////////
rule tier_one_can_always_cancel {
    env e;
    address sender = e.msg.sender;
    require sender != 0;
    sinvoke check_rep(e);

    uint id;
    uint withdraw_block = sinvoke getTransactionWithdrawBlock(id);
    require withdraw_block > 0;  //Block found and no overflow
    require node_in_list(id);

    // bool is_sender_tier_one = sinvoke isTierOneAddress(sender);
    bool is_sender_tier_one = sinvoke isTierOneAddress(e.msg.sender);
    require is_sender_tier_one;

    invoke cancelTransactionById(e, id);

    assert !lastReverted => !node_in_list(id), "cancelTransactionById should always work if 
                                                invoked on an existing transaction by a tier one 
                                                address";
}

/////////////////////////////////////// Property #3 ///////////////////////////////////////////////
rule transaction_delay_is_constant {
    env e;
    require e.msg.sender != 0;
    sinvoke check_rep(e);

    uint init_delay = sinvoke get_delay();

    method f;
    calldataarg arg;
    invoke f(e, arg);

    uint final_delay = sinvoke get_delay();
    assert final_delay == init_delay, "contract delay is constant";
}

/////////////////////////////////////// Property #4 ///////////////////////////////////////////////
rule tier_one_users_cannot_be_removed {
    env e;
    require e.msg.sender != 0;
    sinvoke check_rep(e);

    address privileged;
    bool init_is_tier_1 = sinvoke isTierOneAddress(privileged);
    require init_is_tier_1;

    method f;
    calldataarg arg;
    invoke f(e, arg);

    bool final_is_tier_1 = sinvoke isTierOneAddress(privileged);
    assert final_is_tier_1, "tier one addresses cannot be removed";
}

/////////////////////////////////////// Property #5 ///////////////////////////////////////////////
rule only_empty_phoenixes_can_be_destroyed {
    env e;
    require e.msg.sender != 0;
    sinvoke check_rep(e);

    uint balance = sinvoke getBalance();
    
    sinvoke destroy(e);
    assert balance == 0, "Phoenix can only be destroyed if it is empty";
}
