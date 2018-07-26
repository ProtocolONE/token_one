import ether from './helpers/ether';
import { advanceBlock } from './helpers/advanceToBlock';
import { increaseTimeTo, duration } from './helpers/increaseTime';
import latestTime from './helpers/latestTime';
import EVMThrow from './helpers/EVMThrow';
import expectThrow from './helpers/expectThrow';

const utils = require('./helpers/Utils');

const should = require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(web3.BigNumber))
  .should();

const Crowdsale = artifacts.require('../contracts/OneCrowdsale.sol');
const SmartToken = artifacts.require('OneSmartToken');

contract('OneCrowdsale', ([owner, wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, refundWallet, investor]) => {
  const rate = new web3.BigNumber(2);

  const softCap = new web3.BigNumber(2000);
  const hardCap = new web3.BigNumber(5000);

  const wei = new web3.BigNumber(1000);
  const purchased_tokens = new web3.BigNumber(1000);

  const bonusShare = new web3.BigNumber(10);
  const weiMinAmount = new web3.BigNumber(1000);
  const bonusRate =  new web3.BigNumber(1000);

  const value = ether(1);

  before(async () => {
    // Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
    await advanceBlock();
  });

  beforeEach(async function () {
    this.startTime = latestTime() + duration.weeks(1);
    this.endTime = this.startTime + duration.weeks(1);
    this.afterEndTime = this.endTime + duration.seconds(1);

    this.bonusRateTime = this.startTime + duration.minutes(1);

    this.crowdsale = await Crowdsale.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);
  });

  it('check token unlock', async function () {
    let {logs} = await this.crowdsale.unlockTokens();
    const event = logs.find(e => e.event === 'TokenUnlocked');
    should.exist(event);
  });

  it('check token lock', async function () {
    const result = await this.crowdsale.unlockTokens();
    assert.equal(result.logs[0].event, 'TokenUnlocked');

    const unresult = await this.crowdsale.lockTokens();
    assert.equal(unresult.logs[0].event, 'TokenLocked');
  }); 

  it('buy tokens check', async function () {
    // Adding deal to register
    const bonusWallet = new web3.BigNumber(1000);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    let result = await this.crowdsale.sendTransaction({ value: 1001, from: investor })
    assert.equal(result.logs[0].event, 'DepositAdded');    
    let item = await this.crowdsale.investorsMap.call(investor);
    assert.equal(item[0], wallet);
  });   

  it('assign timelock check', async function () {
    // Adding deal to register
    const mainCliffTime = new web3.BigNumber(80);
    const mainCliffAmount = new web3.BigNumber(80);
    const additionalCliffAmount = new web3.BigNumber(10);
    const additionalCliffTime = new web3.BigNumber(90);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    let result = await this.crowdsale.assignDepositTimeLock(investor, mainCliffAmount, mainCliffTime, additionalCliffAmount, additionalCliffTime);
    assert.equal(result.logs[0].event, 'DepositTimeLockAssigned');    
  });

  it('delete timelock deposit', async function () {
    // Adding deal to register
    const mainCliffTime = new web3.BigNumber(80);
    const mainCliffAmount = new web3.BigNumber(80);
    const additionalCliffAmount = new web3.BigNumber(10);
    const additionalCliffTime = new web3.BigNumber(90);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    let result = await this.crowdsale.assignDepositTimeLock(investor, mainCliffAmount, mainCliffTime, additionalCliffAmount, additionalCliffTime);
    assert.equal(result.logs[0].event, 'DepositTimeLockAssigned');

    result = await this.crowdsale.deleteDepositTimeLock(investor);
    assert.equal(result.logs[0].event, 'DepositTimeLockDeleted');
  });

  it('refund deposit', async function () {
    // Adding deal to register
    const bonusWallet = new web3.BigNumber(1000);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    // Sending transaction to buy tokens
    let result = await this.crowdsale.sendTransaction({ value: 1001, from: investor })
    assert.equal(result.logs[0].event, 'DepositAdded');    
    let item = await this.crowdsale.investorsMap.call(investor);
    assert.equal(item[0], wallet);
    
    let resItem = await this.crowdsale.depositMap.call(wallet);
    assert.equal(resItem[0], investor);

    // Sending
    await this.crowdsale.sendTransaction({ value: 1001, from: wallet })
    let resultBack = await this.crowdsale.refundDeposit(wallet);
    assert.equal(resultBack.logs[0].event, 'RefundedDeposit');    
  });

  it('finish crowdsale', async function () {
    // Adding deal to register
    const bonusWallet = new web3.BigNumber(1000);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    // Sending transaction to buy tokens
    let result = await this.crowdsale.sendTransaction({ value: 1001, from: investor })
    assert.equal(result.logs[0].event, 'DepositAdded');    
    let item = await this.crowdsale.investorsMap.call(investor);
    assert.equal(item[0], wallet);

    await increaseTimeTo(this.afterEndTime);    
    let resultFinish = await this.crowdsale.finishCrowdsale();
    assert.equal(resultFinish.logs[0].event, 'CrowdsakeFinished');        
  });

  it('claim tokens crowdsale check', async function () {
    // Adding deal to register
    const bonusWallet = new web3.BigNumber(1000);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    // Sending transaction to buy tokens
    let result = await this.crowdsale.sendTransaction({ value: 1001, from: investor })
    assert.equal(result.logs[0].event, 'DepositAdded');    
    let item = await this.crowdsale.investorsMap.call(investor);
    assert.equal(item[0], wallet);
    
    // Updating kyc
    await this.crowdsale.updateInvestorKYC(wallet, true);

    // Finishing
    await increaseTimeTo(this.afterEndTime);    
    let resultFinish = await this.crowdsale.finishCrowdsale();
    assert.equal(resultFinish.logs[0].event, 'CrowdsakeFinished');

    await this.crowdsale.claimTokens.call({from : wallet});
  });

  it('return instance create exception with 0 wallet', async () => {
    const startTime = latestTime() + duration.weeks(1);
    const endTime = startTime + duration.weeks(1);

    await expectThrow(
        Crowdsale.new(
            0,
            walletTeam,
            walletAdvisers,
            walletOperating,
            walletReserve,
            walletBounty,
            startTime,
            endTime,
            softCap,
            hardCap
        )
    );
  });

  it('return instance create exception with 0 walletTeam', async () => {
      const startTime = latestTime() + duration.weeks(1);
      const endTime = startTime + duration.weeks(1);

      await expectThrow(
          Crowdsale.new(
              wallet,
              0,
              walletAdvisers,
              walletOperating,
              walletReserve,
              walletBounty,
              startTime,
              endTime,
              softCap,
              hardCap
          )
      );
    });

  it('return instance create exception with 0 walletAdvisers', async () => {
    const startTime = latestTime() + duration.weeks(1);
    const endTime = startTime + duration.weeks(1);

    await expectThrow(
        Crowdsale.new(
            wallet,
            walletTeam,
            0,
            walletOperating,
            walletReserve,
            walletBounty,
            startTime,
            endTime,
            softCap,
            hardCap
        )
    );
  });

  it('return instance create exception with 0 walletAdvisers', async () => {
    const startTime = latestTime() + duration.weeks(1);
    const endTime = startTime + duration.weeks(1);

    await expectThrow(
        Crowdsale.new(
            wallet,
            walletTeam,
            0,
            walletOperating,
            walletReserve,
            walletBounty,
            startTime,
            endTime,
            softCap,
            hardCap
        )
    );
  });

  it('return instance create exception with 0 walletOperating', async () => {
    const startTime = latestTime() + duration.weeks(1);
    const endTime = startTime + duration.weeks(1);

    await expectThrow(
        Crowdsale.new(
            wallet,
            walletTeam,
            walletAdvisers,
            0,
            walletReserve,
            walletBounty,
            startTime,
            endTime,
            softCap,
            hardCap
        )
    );
  });

  it('return instance create exception with 0 walletReserve', async () => {
    const startTime = latestTime() + duration.weeks(1);
    const endTime = startTime + duration.weeks(1);

    await expectThrow(
        Crowdsale.new(
            wallet,
            walletTeam,
            walletAdvisers,
            walletOperating,
            0,
            walletBounty,
            startTime,
            endTime,
            softCap,
            hardCap
        )
    );
  });

  it('return instance create exception with 0 walletBounty', async () => {
    const startTime = latestTime() + duration.weeks(1);
    const endTime = startTime + duration.weeks(1);

    await expectThrow(
        Crowdsale.new(
            wallet,
            walletTeam,
            walletAdvisers,
            walletOperating,
            walletReserve,
            0,
            startTime,
            endTime,
            softCap,
            hardCap
        )
    );
  });

  it('onlyKYCPassed exception', async function () {
    const bonusWallet = new web3.BigNumber(1000);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    await this.crowdsale.sendTransaction({ value: 1001, from: investor })
    await this.crowdsale.investorsMap.call(investor);

    await increaseTimeTo(this.afterEndTime);
    await this.crowdsale.finishCrowdsale();

    await expectThrow(this.crowdsale.claimTokens.call({from : wallet}));
  });
});