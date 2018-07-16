const OneCoin = artifacts.require('./OneSmartToken.sol');
const OneCrowdsale = artifacts.require('./OneCrowdsale.sol');

module.exports = function (deployer, network, accounts) {
  // Change to real params when deploying to eth node

  const openingTime = web3.eth.getBlock(web3.eth.blockNumber).timestamp + 60 * 2;
  const closingTime = openingTime + 86400 * 232; // 232 days

  const wallet = accounts[0];
  const walletTeam = accounts[1];
  const walletAdvisers = accounts[2];
  const walletOperating = accounts[3];
  const walletReserve = accounts[4];
  const walletBounty = accounts[5];

  const softcap = new web3.BigNumber('5000000000000000000000');
  const hardcap = new web3.BigNumber('45000000000000000000000');

  return deployer.then(() => deployer.deploy(OneCoin, wallet, { gas: 100000000 }))
    .then(() => deployer.deploy(
      OneCrowdsale,
      wallet,
      walletTeam,
      walletAdvisers,
      walletOperating,
      walletReserve,
      walletBounty,
      openingTime,
      closingTime,
      softcap,
      hardcap,
      { gas: 100000000 }
    ));
};
