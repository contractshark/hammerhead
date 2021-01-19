pragma specify 0.1

methods {
    isTierOneAddress(address) returns bool envfree
    isTierTwoAddress(address) returns bool envfree
    getTransactionInitiator(uint256) returns address envfree
}

/////////////////////////////////////// Property #6 ///////////////////////////////////////////////
rule no_address_is_both_tier_one_and_tier_two {
    env e;
    require e.msg.sender != 0;
    sinvoke check_rep(e);

    address candidate;
    bool is_tier_one_before = sinvoke isTierOneAddress(candidate);
    bool is_tier_two_before = sinvoke isTierTwoAddress(candidate);
    require !(is_tier_one_before && is_tier_two_before);

    calldataarg arg;
    method f;
    sinvoke f(e, arg);

    bool is_tier_one_after = sinvoke isTierOneAddress(candidate);
    bool is_tier_two_after = sinvoke isTierTwoAddress(candidate);
    assert !(is_tier_one_after && is_tier_two_after), "An address cannot be both tier one and tier two";
}

/////////////////////////////////////// Property #7 ///////////////////////////////////////////////
rule only_tier_one_addresses_can_add_tier_one_addresses {
    env e;
    sinvoke check_rep(e);

    address sender = e.msg.sender;
    require (sender != 0);
    bool is_tier_one = sinvoke isTierOneAddress(sender);

    calldataarg arg;

    sinvoke addTierOne(e, arg);

    assert is_tier_one, "only tier 1 address can add tier 2 address";
}

/////////////////////////////////////// Property #8 //////////////////////////////////////////////
rule only_tier_two_addresses_can_add_transactions {
    env e;
    sinvoke check_rep(e);
    address sender = e.msg.sender;
    require (sender != 0);

    bool is_tier_two = sinvoke isTierTwoAddress(sender);

    calldataarg arg;

    sinvoke addTransaction(e, arg);

    assert is_tier_two, "only tier 2 address can add transactions";
}

/////////////////////////////////////// Property #9 //////////////////////////////////////////////

rule tier_two_addresses_cannot_cancel_other_tier_2_transfers_1 {
    env e;
    sinvoke check_rep(e);
    address sender = e.msg.sender;
    require (sender != 0);
    bool is_tier_one = sinvoke isTierOneAddress(sender);

    sinvoke clearAllPayments(e);

    assert is_tier_one, "tier two addresses cannot cancel other tier 2 transfers";
}

rule tier_two_addresses_cannot_cancel_other_tier_2_transfers_2 {
    env e;
    sinvoke check_rep(e);
    address sender = e.msg.sender;
    require (sender != 0);
    bool is_tier_one = sinvoke isTierOneAddress(sender);

    calldataarg arg;

    sinvoke cancelTransactionById(e, arg);

    assert is_tier_one, "tier two addresses cannot cancel other tier 2 transfers";
}

rule tier_two_addresses_cannot_cancel_other_tier_2_transfers_3 {
    env e;
    sinvoke check_rep(e);
    address sender = e.msg.sender;
    require (sender != 0);
    bool is_tier_one = sinvoke isTierOneAddress(sender);

    uint256 id;
    address initiator = sinvoke getTransactionInitiator(id);
    require initiator != e.msg.sender;

    sinvoke cancelTransactionById(e, id);

    assert is_tier_one, "tier two addresses cannot cancel other tier 2 transfers";
}
