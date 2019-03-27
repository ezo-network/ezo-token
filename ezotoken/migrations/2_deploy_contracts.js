var EZOToken = artifacts.require("./EZOToken.sol");

module.exports = function(deployer) {
  deployer.deploy(EZOToken);
};
