const OneCoin = artifacts.require('./OneSmartToken.sol');
const OneCrowdsale = artifacts.require('./OneCrowdsale.sol');

module.exports = function (deployer, network, accounts) {
  const openingTime = web3.eth.getBlock(web3.eth.blockNumber).timestamp + 10; // 10 seconds from now;
  const closingTime = openingTime + 86400 * 20; // 20 days
  const rate = new web3.BigNumber(1000);
  const wallet = accounts[0]; // Second account

  return deployer.then(() => deployer.deploy(OneCoin)).then(() => deployer.deploy(OneCrowdsale, openingTime, closingTime, rate, wallet, OneCoin.address));
};
