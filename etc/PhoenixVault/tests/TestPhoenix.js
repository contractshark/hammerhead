const LedgerLib = artifacts.require("LedgerLib");
const Phoenix = artifacts.require("Phoenix");
const truffleAssert = require('truffle-assertions');
const test_util = require('./util/test_util');


contract("JS Phoenix test", async accounts => {
  let owner = accounts[0];
  let spender1 = accounts[1];
  let spender2 = accounts[2];
  let hacker = accounts[3];

  let MIN_DELAY = 4;
  let MAX_DELAY = Math.pow(2, 32);
  let AVE_DELAY = 6 * 60 * 24;

  it("Constructor and Destructor", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);

    assert(AVE_DELAY < MAX_DELAY);
    let typical_use_case_phoenix = await Phoenix.new(owner, spender1, AVE_DELAY, 10, {from: spender1});
    let phoenix_balance = await web3.eth.getBalance(typical_use_case_phoenix.address);
    assert.equal(phoenix_balance, 0);
    await truffleAssert.reverts(typical_use_case_phoenix.destroy({from: spender1})); // only tier 1 can destroy
    await typical_use_case_phoenix.destroy();

    let minimal_phoenix = await Phoenix.new(owner, spender1, MIN_DELAY, 1, {from: spender1});
    phoenix_balance = await web3.eth.getBalance(minimal_phoenix.address);
    assert.equal(phoenix_balance, 0);
    await minimal_phoenix.destroy();

    let stress_test_phoenix = await Phoenix.new(owner, spender1, 10000, 100, {from: spender1});
    phoenix_balance = await web3.eth.getBalance(stress_test_phoenix.address);
    assert.equal(phoenix_balance, 0);
    await stress_test_phoenix.destroy();

    await truffleAssert.reverts(Phoenix.new(owner, owner, 0, 10, {from: spender1})); // Address cannot be both tiers
    await truffleAssert.reverts(Phoenix.new(spender1, spender1, 0, 10, {from: spender1})); // Address cannot be both tiers

    await truffleAssert.reverts(Phoenix.new(owner, spender1, AVE_DELAY, 10, {from: owner})); // sender cannot be the tier1

    await truffleAssert.reverts(Phoenix.new(owner, spender1, 0, 10, {from: spender1})); // No delay
    await truffleAssert.reverts(Phoenix.new(owner, spender1, 1, 10, {from: spender1})); // No delay
    await truffleAssert.reverts(Phoenix.new(owner, spender1, MIN_DELAY/2, 10, {from: spender1})); // delay too small
    await truffleAssert.reverts(Phoenix.new(owner, spender1, MIN_DELAY - 1, 10, {from: spender1})); // delay too small
    await truffleAssert.reverts(Phoenix.new(owner, spender1, MAX_DELAY + 1, 10, {from: spender1})); // delay too big
    await truffleAssert.reverts(Phoenix.new(owner, spender1, 100 * MAX_DELAY, 10, {from: spender1})); // delay too big
    await truffleAssert.passes(Phoenix.new(owner, spender1, MIN_DELAY, 10, {from: spender1}));
    await truffleAssert.passes(Phoenix.new(owner, spender1, MAX_DELAY, 10, {from: spender1}));

    await truffleAssert.reverts(Phoenix.new(owner, spender1, AVE_DELAY, 0, {from: spender1})); // No transactions
  });

  it("lock()", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, AVE_DELAY, 10, {from: spender1});

    let call_res = await phoenix.lock(0); // should succeed
    let block_number = await web3.eth.getBlockNumber();
    truffleAssert.eventEmitted(call_res, "Lock", (ev) => {
      return ev.unlocked_at == block_number;
    });

    call_res = await phoenix.lock(2); // increasing lock is legal
    block_number = await web3.eth.getBlockNumber();
    truffleAssert.eventEmitted(call_res, "Lock", (ev) => {
      return ev.unlocked_at == block_number + 2;
    });

    call_res = await phoenix.lock(8); // increasing lock is legal
    block_number = await web3.eth.getBlockNumber();
    truffleAssert.eventEmitted(call_res, "Lock", (ev) => {
      return ev.unlocked_at == block_number + 8;
    });

    await truffleAssert.reverts(phoenix.lock(5)); //Cannot decrease lock
    await truffleAssert.reverts(phoenix.lock(20, {from: hacker})); //Only Tier 1
    test_util.mineNBlocks(8);
    call_res = await phoenix.lock(2); // increasing lock is legal
    block_number = await web3.eth.getBlockNumber();
    truffleAssert.eventEmitted(call_res, "Lock", (ev) => {
      return ev.unlocked_at == block_number + 2;
    });

    await truffleAssert.reverts(phoenix.destroy()); // Cannot destroy while phoenix is locked

    test_util.mineNBlocks(2);
    await truffleAssert.passes(phoenix.destroy());
  });

  it("addTierOne()", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, AVE_DELAY, 10, {from: spender1});

    await truffleAssert.reverts(phoenix.addTierOne(owner)); // owner already a tier one silly

    await truffleAssert.reverts(phoenix.addTierOne(hacker, {from: hacker})); // only a tier one can invoke this

    await truffleAssert.passes(phoenix.lock(2));
    await truffleAssert.reverts(phoenix.addTierOne(spender1)); // cannot add when phoenix is locked
    test_util.mineNBlocks(2);

    await truffleAssert.passes(phoenix.addTierOne(spender2));

    await truffleAssert.reverts(phoenix.addTierOne(spender2)); // already there

    await truffleAssert.passes(phoenix.destroy());
  });

  it("addTierTwo()", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, accounts[7], AVE_DELAY, 10, {from: spender1});

    await truffleAssert.passes(phoenix.addTierTwo(spender1));

    await truffleAssert.reverts(phoenix.addTierTwo(owner)); // already tier one
    await truffleAssert.reverts(phoenix.addTierTwo(spender1)); // already there
    await truffleAssert.reverts(phoenix.addTierTwo(spender2, {from: spender1})); // only tier one can
    await truffleAssert.reverts(phoenix.addTierTwo(spender2, {from: hacker})); // only tier one can

    await truffleAssert.passes(phoenix.lock(2));
    await truffleAssert.reverts(phoenix.addTierTwo(spender2)); // cannot add when phoenix is locked
    test_util.mineNBlocks(2);

    await truffleAssert.passes(phoenix.addTierTwo(spender2));

    await truffleAssert.passes(phoenix.destroy());
  });

  it("tiers and locks interaction", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, AVE_DELAY, 10, {from: spender1});

    await truffleAssert.reverts(phoenix.addTierOne(spender2, {from: spender1})); // only tier one can
    await truffleAssert.reverts(phoenix.lock(2, {from: spender1})); // only tier one can

    await truffleAssert.passes(phoenix.destroy());
  });

  it("removeTierTwo", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, AVE_DELAY, 10, {from: spender1});

    await truffleAssert.reverts(phoenix.removeTierTwo(spender2)); // Not in tier two list
    await truffleAssert.reverts(phoenix.removeTierTwo(owner)); // Not in tier two list
    await truffleAssert.reverts(phoenix.removeTierTwo(spender1, {from: spender1})); // only tier one can
    await truffleAssert.reverts(phoenix.removeTierTwo(spender1, {from: hacker})); // only tier one can

    await truffleAssert.passes(phoenix.lock(2));
    await truffleAssert.reverts(phoenix.removeTierTwo(spender1)); // only tier one can
    test_util.mineNBlocks(2);

    let call_res = await phoenix.removeTierTwo(spender1);
    truffleAssert.eventEmitted(call_res, "Fired", (ev) =>{
      return ev.former_tier_two == spender1;
    });

    await truffleAssert.reverts(phoenix.removeTierTwo(spender1)); // Not in tier two list anymore :(

    await truffleAssert.passes(phoenix.destroy());
  });

  it("fallback - payment to phoenix", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, AVE_DELAY, 10, {from: spender1});

    let phoenix_balance = await web3.eth.getBalance(phoenix.address);
    assert.equal(phoenix_balance, 0); //No payments yet

    await truffleAssert.passes(phoenix.lock(20)); // Money can be sent in even when the phoenix is locked

    let call_res = await phoenix.send(web3.utils.toWei('1', "ether"), {from: owner});
    truffleAssert.eventEmitted(call_res, "Deposit", (ev) => {
      return ev.amount == web3.utils.toWei('1', "ether");
    });
    phoenix_balance = await web3.eth.getBalance(phoenix.address);
    assert.equal(phoenix_balance, web3.utils.toWei('1', "ether"));

    call_res = await phoenix.send(web3.utils.toWei('1', "ether"), {from: spender1});
    truffleAssert.eventEmitted(call_res, "Deposit", (ev) =>{
      return ev.amount == web3.utils.toWei('1', "ether");
    });
    phoenix_balance = await web3.eth.getBalance(phoenix.address);
    assert.equal(phoenix_balance, web3.utils.toWei('2', "ether"));
    
    call_res = await phoenix.send(web3.utils.toWei('1', "ether"), {from: spender2});
    truffleAssert.eventEmitted(call_res, "Deposit", (ev) => {
      return ev.amount == web3.utils.toWei('1', "ether");
    });
    phoenix_balance = await web3.eth.getBalance(phoenix.address);
    assert.equal(phoenix_balance, web3.utils.toWei('3', "ether"));

    call_res = await phoenix.send(web3.utils.toWei('1', "ether"), {from: hacker});
    truffleAssert.eventEmitted(call_res, "Deposit", (ev) => {
      return ev.amount == web3.utils.toWei('1', "ether");
    });
    phoenix_balance = await web3.eth.getBalance(phoenix.address);
    assert.equal(phoenix_balance, web3.utils.toWei('4', "ether"));

    await truffleAssert.reverts(phoenix.destroy()); // only an empty phoenix can be destroyed
  });

  it("addTransaction()", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, 10, 2, {from: spender1});
    await truffleAssert.passes(phoenix.send(web3.utils.toWei('3', "ether"), {from: owner}));

    await truffleAssert.reverts(phoenix.addTransaction(owner, web3.utils.toWei('1', "ether"), {from: hacker})); // only tier 2 can do it
    await truffleAssert.reverts(phoenix.addTransaction(owner, web3.utils.toWei('1', "ether"), {from: owner})); // only tier 2 can do it
    await truffleAssert.reverts(phoenix.addTransaction(owner, web3.utils.toWei('4', "ether"), {from: spender1})); // not enough money
    await truffleAssert.reverts(phoenix.addTransaction(phoenix.address, web3.utils.toWei('4', "ether"), {from: spender1})); // phoenix cannot pay itself
    await truffleAssert.reverts(phoenix.addTransaction('0x0000000000000000000000000000000000000000', web3.utils.toWei('4', "ether"), {from: spender1})); // phoenix cannot pay itself

    await truffleAssert.passes(phoenix.lock(2));
    await truffleAssert.reverts(phoenix.addTransaction(owner, web3.utils.toWei('2', "ether"), {from: spender1})); // locked
    test_util.mineNBlocks(2);

    let call_res = await phoenix.addTransaction(spender2, web3.utils.toWei('1', "ether"), {from: spender1});
    truffleAssert.eventEmitted(call_res, "Request", (ev) => {
      return ev.to == spender2 && ev.amount == web3.utils.toWei('1', "ether") && ev.id == 1 && ev.from == spender1;
    });

    call_res = await phoenix.addTransaction(spender1, web3.utils.toWei('1', "ether"), {from: spender1});
    truffleAssert.eventEmitted(call_res, "Request", (ev) => {
      return ev.to == spender1 && ev.amount == web3.utils.toWei('1', "ether") && ev.id == 2 && ev.from == spender1;
    });

    await truffleAssert.reverts(phoenix.addTransaction(hacker, web3.utils.toWei('1', "ether"), {from: spender1}));  //transaction list is full

    test_util.mineNBlocks(10);

    await truffleAssert.reverts(phoenix.addTransaction(hacker, web3.utils.toWei('1', "ether"), {from: spender1}));  //transaction list is still full, no payment was comitted
  });

  it("check if removing tier 2 accounts removes its transactions", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, 10, 2, {from: spender1});
    await truffleAssert.passes(phoenix.addTierTwo(spender2));
    await truffleAssert.passes(phoenix.send(3, {from: owner}));

    await truffleAssert.passes(phoenix.addTransaction(spender2, 2, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(spender2, 1, {from: spender2}));

    let call_res = await phoenix.removeTierTwo(spender1);
    truffleAssert.eventEmitted(call_res, "Fired", (ev) => {
      return ev.former_tier_two == spender1;
    });

    //Now we have a commitment of only 1 ether in the ledger
    await truffleAssert.reverts(phoenix.addTransaction(owner, 3, {from: spender2}));

    call_res = await phoenix.addTransaction(owner, 2, {from: spender2});
    truffleAssert.eventEmitted(call_res, "Request", (ev) => {
      return ev.to == owner && ev.from == spender2 && ev.amount == 2;
    });

    // Now we empty the ledger
    call_res = await phoenix.removeTierTwo(spender2);
    truffleAssert.eventEmitted(call_res, "Fired", (ev) => {
      return ev.former_tier_two == spender2;
    });

    // Now we test removing all transaction inititated by a tier to in a ledger of length 1

    await truffleAssert.passes(phoenix.addTierTwo(spender2));

    call_res = await phoenix.addTransaction(owner, 3, {from: spender2});
    truffleAssert.eventEmitted(call_res, "Request", (ev) => {
      return ev.to == owner && ev.from == spender2 && ev.amount == 3;
    });

    // Now we empty the ledger
    call_res = await phoenix.removeTierTwo(spender2);
    truffleAssert.eventEmitted(call_res, "Fired", (ev) => {
      return ev.former_tier_two == spender2;
    });

  });


  it("withdraw()", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, 10, 10, {from: spender1});
    await truffleAssert.passes(phoenix.send(5, {from: owner}));

    await truffleAssert.passes(phoenix.addTransaction(owner, 1, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 1, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 1, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 1, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 1, {from: spender1}));

    await truffleAssert.reverts(phoenix.withdraw(0, {from: spender2})); // not enough time has passed
    test_util.mineNBlocks(10);


    await truffleAssert.passes(phoenix.lock(2));
    await truffleAssert.reverts(phoenix.withdraw(0, {from: spender2})); // cannot withdraw when phoenix is locked
    test_util.mineNBlocks(3);

    let call_res = await phoenix.withdraw(1, {from: owner}); //works
    truffleAssert.eventEmitted(call_res, "Withdrawal", (ev) => {
      return ev.to == owner && ev.id == 1 && ev.amount == 1;
    });

    call_res = await phoenix.withdraw(2, {from: spender1}); //works
    truffleAssert.eventEmitted(call_res, "Withdrawal", (ev) => {
      return ev.to == owner && ev.id == 2 && ev.amount == 1;
    });

    call_res = await phoenix.withdraw(3, {from: spender2}); //works
    truffleAssert.eventEmitted(call_res, "Withdrawal", (ev) => {
      return ev.to == owner && ev.id == 3 && ev.amount == 1;
    });

    call_res = await phoenix.withdraw(4, {from: hacker}); //works
    truffleAssert.eventEmitted(call_res, "Withdrawal", (ev) => {
      return ev.to == owner && ev.id == 4 && ev.amount == 1;
    });

    call_res = await phoenix.withdraw(5, {from: accounts[8]}); //works
    truffleAssert.eventEmitted(call_res, "Withdrawal", (ev) => {
      return ev.to == owner && ev.id == 5 && ev.amount == 1;
    });

    await truffleAssert.reverts(phoenix.withdraw(0, {from: spender2})); //was already withdrawn

    await truffleAssert.passes(phoenix.destroy()); //phoenix now empty
  });

  it("clearAllPayments()", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, MIN_DELAY, 10, {from: spender2});
    await truffleAssert.passes(phoenix.send(5, {from: owner}));

    await truffleAssert.passes(phoenix.addTransaction(owner, 2, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 2, {from: spender1}));
    await truffleAssert.reverts(phoenix.addTransaction(owner, 2, {from: spender1})); // its full

    await truffleAssert.reverts(phoenix.clearAllPayments({from: spender1})); // only tier 1
    await truffleAssert.passes(phoenix.lock(2));

    let call_res = await phoenix.clearAllPayments({from: owner}); // works even when locked
    truffleAssert.eventEmitted(call_res, "Reset");


    call_res = await phoenix.clearAllPayments({from: owner}); // can do it twice
    truffleAssert.eventEmitted(call_res, "Reset");

    await truffleAssert.passes(phoenix.addTransaction(owner, 5, {from: spender1})); // because phoenix is empty
    
    test_util.mineNBlocks(MIN_DELAY);
    await truffleAssert.passes(phoenix.withdraw(3));
    
    await truffleAssert.passes(phoenix.clearAllPayments({from: owner})); // works even when there are no payments to clear

    await truffleAssert.passes(phoenix.destroy()); // works because the phoenix is empty
  });

  it("cancelTransactionById()", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, 100, 6, {from: spender1});
    await truffleAssert.passes(phoenix.send(10, {from: owner}));

    let call_res = await phoenix.addTransaction(owner, 1, {from: spender1});

    truffleAssert.eventEmitted(call_res, "Request", (ev) => {
      return ev.to == owner && ev.amount == 1 && ev.id == 1;
    });

    await truffleAssert.passes(phoenix.addTransaction(owner, 2, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 3, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 4, {from: spender1}));

    await truffleAssert.reverts(phoenix.addTransaction(owner, 2, {from: spender1})); //We're spending 10 currently

    call_res = await phoenix.cancelTransactionById(2, {from: owner});
    truffleAssert.eventEmitted(call_res, "Cancellation", (ev) => {
      return ev.id == 2 && ev.amount == 2;
    });

    await truffleAssert.reverts(phoenix.addTransaction(owner, 5, {from: spender1})); //We're spending 8 currently
    await truffleAssert.passes(phoenix.addTransaction(owner, 2, {from: spender1}));

    await truffleAssert.reverts(phoenix.cancelTransactionById(2, {from: owner})); //was already cancelled before
    await truffleAssert.reverts(phoenix.cancelTransactionById(29, {from: owner})); //No such transaction
    await truffleAssert.reverts(phoenix.cancelTransactionById(3, {from: spender1})); //only tier1

    call_res = await phoenix.cancelTransactionById(1); //delete first transaction
    truffleAssert.eventEmitted(call_res, "Cancellation", (ev) => {
      return ev.id == 1 && ev.amount == 1;
    });

    call_res = await phoenix.cancelTransactionById(5); //delete last transaction
    truffleAssert.eventEmitted(call_res, "Cancellation", (ev) => {
      return ev.id == 5 && ev.amount == 2;
    });

  });

  it("cancelMyTransaction()", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, 100, 6, {from: spender1});
    await truffleAssert.passes(phoenix.send(10, {from: owner}));

    let phoenix_balance = await web3.eth.getBalance(phoenix.address);
    assert.equal(phoenix_balance, 10);

    await truffleAssert.passes(phoenix.addTransaction(owner, 1, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 2, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 3, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 4, {from: spender1}));


    await truffleAssert.reverts(phoenix.addTransaction(owner, 2, {from: spender1})); //We're spending 10 currently

    let call_res = await phoenix.cancelMyTransaction(2, {from: spender1});
    truffleAssert.eventEmitted(call_res, "Cancellation", (ev) => {
      return ev.id == 2 && ev.amount == 2;
    });

    await truffleAssert.reverts(phoenix.addTransaction(owner, 5, {from: spender1})); //We're spending 8 currently
    await truffleAssert.passes(phoenix.addTransaction(owner, 2, {from: spender1}));

    await truffleAssert.reverts(phoenix.cancelMyTransaction(2, {from: spender1})); //was already cancelled before
    await truffleAssert.reverts(phoenix.cancelMyTransaction(29, {from: spender1})); //No such transaction
    await truffleAssert.reverts(phoenix.cancelMyTransaction(3, {from: owner})); //only tier2
    await truffleAssert.reverts(phoenix.cancelMyTransaction(3, {from: hacker})); //only transaction initiator

    call_res = await phoenix.cancelMyTransaction(1, {from: spender1}); //delete first transaction
    truffleAssert.eventEmitted(call_res, "Cancellation", (ev) => {
      return ev.id == 1 && ev.amount == 1;
    });

    call_res = await phoenix.cancelMyTransaction(5, {from: spender1}); //delete last transaction
    truffleAssert.eventEmitted(call_res, "Cancellation", (ev) => {
      return ev.id == 5 && ev.amount == 2;
    });
  });

  it("cancel a transaction from a ledger of size 1", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, 100, 1, {from: spender1});
    await truffleAssert.passes(phoenix.send(10, {from: hacker}));

    for (i = 1; i<10; i++){
      let call_res = await phoenix.addTransaction(owner, i, {from: spender1});
      truffleAssert.eventEmitted(call_res, "Request", (ev) => {
        return ev.to == owner && ev.amount == i && ev.id == i && ev.from == spender1;
      });

      call_res = await phoenix.cancelMyTransaction(i, {from: spender1});
      truffleAssert.eventEmitted(call_res, "Cancellation", (ev) => {
        return ev.id == i && ev.amount == i;
      });
    }
  });

  it("avoiding oveflow in addTransaction()", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, 10, 4, {from: spender1});
    await truffleAssert.passes(phoenix.send(3, {from: owner}));

    let call_res = await phoenix.addTransaction(spender2, 2, {from: spender1});
    truffleAssert.eventEmitted(call_res, "Request", (ev) => {
      return ev.to == spender2 && ev.amount == 2 && ev.id == 1 && ev.from == spender1;
    });

    let UINT256_MAX = 2^256 - 1;

    await truffleAssert.reverts(phoenix.addTransaction(hacker, UINT256_MAX, {from: spender1}));  //overflow
  });

  it("deletions_interactions()", async function() {
    const ledger = await LedgerLib.new();
    await Phoenix.link(LedgerLib, ledger.address);
    let phoenix = await Phoenix.new(owner, spender1, MIN_DELAY, 20, {from: spender1});
    await truffleAssert.passes(phoenix.send(5, {from: owner}));
    await truffleAssert.passes(phoenix.addTierTwo(spender2, {from: owner}));

    await truffleAssert.passes(phoenix.addTransaction(owner, 1, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 1, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 1, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 1, {from: spender1}));
    await truffleAssert.passes(phoenix.addTransaction(owner, 1, {from: spender2}));

    test_util.mineNBlocks(MIN_DELAY);

    // // Withdraw succeeds, all other deletions fail
    await truffleAssert.passes(phoenix.withdraw(1, {from: spender2}));
    await truffleAssert.reverts(phoenix.cancelTransactionById(1, {from: owner}));
    await truffleAssert.reverts(phoenix.cancelMyTransaction(1, {from: spender1}));

    // // Delete by ID succeeds, all other deletions fail
    await truffleAssert.passes(phoenix.cancelTransactionById(2, {from: owner}));
    await truffleAssert.reverts(phoenix.withdraw(2, {from: spender2}));
    await truffleAssert.reverts(phoenix.cancelMyTransaction(2, {from: spender1}));

    // Delete My transaction passes, all other deletions fail
    await truffleAssert.passes(phoenix.cancelMyTransaction(3, {from: spender1}));
    await truffleAssert.reverts(phoenix.withdraw(3, {from: spender2}));
    await truffleAssert.reverts(phoenix.cancelTransactionById(3, {from: owner}));

    // Deleted by removing the user, all other deletions fail
    await truffleAssert.passes(phoenix.removeTierTwo(spender1, {from: owner}));
    await truffleAssert.passes(phoenix.addTierTwo(spender1, {from: owner}));
    await truffleAssert.reverts(phoenix.cancelMyTransaction(4, {from: spender1}));
    await truffleAssert.reverts(phoenix.withdraw(4, {from: spender2}));
    await truffleAssert.reverts(phoenix.cancelTransactionById(4, {from: owner}));

    //Deleted by remove all transactions, all other deletions fail
    await truffleAssert.passes(phoenix.clearAllPayments({from: owner}));
    await truffleAssert.reverts(phoenix.withdraw(5, {from: spender2}));
    await truffleAssert.reverts(phoenix.cancelTransactionById(5, {from: owner}));
  });

});