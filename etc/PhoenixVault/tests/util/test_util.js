//This file includes utilities useful for testing

const { promisify } = require('util');

module.exports = {
  mineNBlocks: async function (n) {
    assert(n >= 0, 'number of blocks to mine cannot be negative');
    for (i = 0; i < n; i++) {
      promisify(web3.currentProvider.send.bind(web3.currentProvider))({
        jsonrpc: '2.0',
        method: 'evm_mine',
        id: new Date().getTime(),
      });
    }
  },
};
