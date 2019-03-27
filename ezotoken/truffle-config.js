const path = require("path");
var HDWalletProvider = require("truffle-hdwallet-provider");

var mnemonic = "Your mnemonic here";

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    ropsten: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "https://ropsten.infura.io/bZU9r1nGjPDFbrV8L6O8");
      },
      network_id: '3',
    }
  }
};
