pragma specify 0.1

methods {
    getBalance() returns uint envfree
    isTierOneAddress(address) returns bool envfree
    lock_timeout() returns uint envfree
}

/////////////////////////////////////// Property #10 ///////////////////////////////////////////////
rule money_cannot_leave_phoenix_if_it_is_locked {
    env e;
    require e.msg.sender != 0;
    sinvoke check_rep(e);

    uint lock_open_time = sinvoke lock_timeout();
    uint init_balance = sinvoke getBalance();

    method f;
    calldataarg arg;
    invoke f(e, arg);

    uint final_balance = sinvoke getBalance();
    uint curr_block = e.block.number;
    bool balance_decreased = (final_balance < init_balance);
    bool lock_opened = (curr_block >= lock_open_time);
    assert balance_decreased => lock_opened,
        "money cannot leave Phoenix if it is locked";
}

/////////////////////////////////////// Property #11 ///////////////////////////////////////////////
rule lock_can_only_be_delayed {
    env e;
    require e.msg.sender != 0;
    sinvoke check_rep(e);

    uint init_lock_open_time = sinvoke lock_timeout();

    method f;
    calldataarg arg;
    invoke f(e, arg);
    
    uint final_lock_open_time = sinvoke lock_timeout();
    assert final_lock_open_time >= init_lock_open_time, 
        "lock open time cannot be advanced";
}

/////////////////////////////////////// Property #12 //////////////////////////////////////////////
rule only_tier_one_addresses_can_lock_phoenix {
    env e;
    sinvoke check_rep(e);

    address sender = e.msg.sender;
    require (sender != 0);
    bool is_tier_one = sinvoke isTierOneAddress(sender);

    calldataarg arg;
    invoke lock(e, arg);

    assert !is_tier_one => lastReverted, "only tier one addresses can lock Phoenix";
}

/////////////////////////////////////// Property #13 //////////////////////////////////////////////
rule only_tier_one_addresses_can_remove_tier_two_addresses {
    env e;
    sinvoke check_rep(e);
    address sender = e.msg.sender;
    require (sender != 0);

    bool is_tier_one = sinvoke isTierOneAddress(sender);

    calldataarg arg;
    invoke removeTierTwo(e, arg);

    assert !is_tier_one => lastReverted, "only tier one addresses can remove tier two addresses";
}

/////////////////////////////////////// Property #14 //////////////////////////////////////////////
rule only_tier_one_addresses_can_add_tier_two_addresses {
    env e;
    sinvoke check_rep(e);

    address sender = e.msg.sender;
    require (sender != 0);
    bool is_tier_one = sinvoke isTierOneAddress(sender);

    calldataarg arg;
    invoke addTierTwo(e, arg);

    assert !is_tier_one => lastReverted, "only tier one addreses can add tier two addresses";
}
