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
const CrowdsaleMock = artifacts.require('./helpers/OneCrowdsaleMock.sol');
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
    this.endTime = this.startTime + duration.years(1);
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

  it('refund deposit catch 1', async function () {
    // Adding deal to register
    const bonusWallet = new web3.BigNumber(1000);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);

    await expectThrow(this.crowdsale.refundDeposit(wallet));
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

  it('onlyWhitelisted exception', async function () {
    const bonusWallet = new web3.BigNumber(1000);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    await expectThrow(this.crowdsale.buyTokens(investor));
  });

  it('addDeposit exception 1', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await expectThrow(this.crowdsaleMock.addDepositMock(0, investor, 10, 10));
  });

  it('addDeposit exception 2', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await expectThrow(this.crowdsaleMock.addDepositMock(investor, 0, 10, 10));
  });

  it('addDeposit exception 3', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await expectThrow(this.crowdsaleMock.addDepositMock(investor, wallet, 10, 0));
  });

  it('rate check 1', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await increaseTimeTo(this.startTime + duration.days(1));

    let r = await this.crowdsaleMock.getBonusRateMocked.call(investor);
    assert.equal(r, 60);
  });

  it('rate check 2', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await increaseTimeTo(this.startTime + duration.days(40));

    let r = await this.crowdsaleMock.getBonusRateMocked.call(investor);
    assert.equal(r, 50);
  });

  it('rate check 3', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await increaseTimeTo(this.startTime + duration.days(70));

    let r = await this.crowdsaleMock.getBonusRateMocked.call(investor);
    assert.equal(r, 40);
  });

  it('rate check 4', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await increaseTimeTo(this.startTime + duration.days(120));

    let r = await this.crowdsaleMock.getBonusRateMocked.call(investor);
    assert.equal(r, 30);
  });

  it('rate check 5', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await increaseTimeTo(this.startTime + duration.days(150));

    let r = await this.crowdsaleMock.getBonusRateMocked.call(investor);
    assert.equal(r, 20);
  });

  it('rate check 6', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await increaseTimeTo(this.startTime + duration.days(210));

    let r = await this.crowdsaleMock.getBonusRateMocked.call(investor);
    assert.equal(r, 10);
  });

  it('rate check 7', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await increaseTimeTo(this.startTime + duration.days(215));

    let r = await this.crowdsaleMock.getBonusRateMocked.call(investor);
    assert.equal(r, 8);
  });

  it('rate check 8', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await increaseTimeTo(this.startTime + duration.days(217));

    let r = await this.crowdsaleMock.getBonusRateMocked.call(investor);
    assert.equal(r, 6);
  });

  it('rate check 9', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await increaseTimeTo(this.startTime + duration.days(222));

    let r = await this.crowdsaleMock.getBonusRateMocked.call(investor);
    assert.equal(r, 4);
  });

  it('rate check 10', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await increaseTimeTo(this.startTime + duration.days(226));

    let r = await this.crowdsaleMock.getBonusRateMocked.call(investor);
    assert.equal(r, 2);
  });

  it('rate check 11', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(wallet, walletTeam, walletAdvisers, walletOperating, walletReserve, walletBounty, 
      this.startTime, this.endTime, softCap, hardCap);

    await increaseTimeTo(this.startTime + duration.days(230));

    let r = await this.crowdsaleMock.getBonusRateMocked.call(investor);
    assert.equal(r, 0);
  });

  it('finishCrowdsale exception 1', async function () {
    await expectThrow(this.crowdsale.finishCrowdsale());
  });

  it('finishCrowdsale exception 2', async function () {
    await increaseTimeTo(this.afterEndTime);
    await this.crowdsale.finishCrowdsale();
    await expectThrow(this.crowdsale.finishCrowdsale());
  });

  it('finishCrowdsale with invoices', async function () {
    const tokens = new web3.BigNumber(1000);
    const invId = "somedInvoiceId";

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdateInvoice(investor, tokens, invId);

    await increaseTimeTo(this.afterEndTime);
    let res = await this.crowdsale.finishCrowdsale();
    assert.equal(res.logs[1].event, "CrowdsakeFinished");
  });

  it('assignDepositTimeLock exception with 0 wallet', async function () {
    const mainCliffTime = new web3.BigNumber(80);
    const mainCliffAmount = new web3.BigNumber(80);
    const additionalCliffAmount = new web3.BigNumber(10);
    const additionalCliffTime = new web3.BigNumber(90);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.assignDepositTimeLock(0, mainCliffAmount, mainCliffTime, additionalCliffAmount, additionalCliffTime));
  });

  it('assignDepositTimeLock exception with 0 mainCliffTime', async function () {
    const mainCliffAmount = new web3.BigNumber(80);
    const additionalCliffAmount = new web3.BigNumber(10);
    const additionalCliffTime = new web3.BigNumber(90);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.assignDepositTimeLock(investor, mainCliffAmount, 0, additionalCliffAmount, additionalCliffTime));
  });

  it('assignDepositTimeLock exception with 0 mainCliffAmount', async function () {
    const mainCliffTime = new web3.BigNumber(80);
    const additionalCliffAmount = new web3.BigNumber(10);
    const additionalCliffTime = new web3.BigNumber(90);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.assignDepositTimeLock(investor, 0, mainCliffTime, additionalCliffAmount, additionalCliffTime));
  });

  it('assignDepositTimeLock exception with mainCliffTime greater than additionalCliffTime', async function () {
    const mainCliffTime = new web3.BigNumber(90);
    const mainCliffAmount = new web3.BigNumber(30);
    const additionalCliffAmount = new web3.BigNumber(10);
    const additionalCliffTime = new web3.BigNumber(20);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.assignDepositTimeLock(investor, mainCliffAmount, mainCliffTime, additionalCliffAmount, additionalCliffTime));
  });

  it('assignDepositTimeLock exception with sum mainCliffAmount and additionalCliffAmount greater than 100', async function () {
    const mainCliffTime = new web3.BigNumber(20);
    const mainCliffAmount = new web3.BigNumber(20);
    const additionalCliffAmount = new web3.BigNumber(90);
    const additionalCliffTime = new web3.BigNumber(90);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.assignDepositTimeLock(investor, mainCliffAmount, mainCliffTime, additionalCliffAmount, additionalCliffTime));
  });

  it('assignDepositTimeLock event AdditionalCliffTimeGreaterThanZero', async function () {
    const mainCliffTime = new web3.BigNumber(80);
    const mainCliffAmount = new web3.BigNumber(80);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    const log = await this.crowdsale.assignDepositTimeLock(investor, mainCliffAmount, mainCliffTime, 0, 0);
    assert.equal(log.logs[0].event, 'AdditionalCliffTimeGreaterThanZero');
  });

  it('deleteDepositTimeLock exception with 0 wallet', async function () {
    const mainCliffTime = new web3.BigNumber(80);
    const mainCliffAmount = new web3.BigNumber(80);
    const additionalCliffAmount = new web3.BigNumber(10);
    const additionalCliffTime = new web3.BigNumber(90);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.assignDepositTimeLock(investor, mainCliffAmount, mainCliffTime, additionalCliffAmount, additionalCliffTime);
    await expectThrow(this.crowdsale.deleteDepositTimeLock(0));
  });

  it('refundDeposit exception with 0 depositedTokens', async function () {
    const bonusWallet = new web3.BigNumber(1000);

    let crowdsaleMock = await CrowdsaleMock.new(
        wallet,
        walletTeam,
        walletAdvisers,
        walletOperating,
        walletReserve,
        walletBounty,
        this.startTime,
        this.endTime,
        softCap,
        hardCap
    );

    await increaseTimeTo(this.startTime);
    await crowdsaleMock.addAdmin(owner);
    await crowdsaleMock.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);
    await crowdsaleMock.sendTransaction({ value: 1001, from: investor })
    await crowdsaleMock.sendTransaction({ value: 1001, from: wallet })

    await crowdsaleMock.setDepositTokens(wallet, 0);

    await expectThrow(this.crowdsale.refundDeposit(wallet));
  });

  it('claimtokens catch finilize', async function () {
     // Adding deal to register
    const bonusWallet = new web3.BigNumber(1000);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    // Updating kyc
    await this.crowdsale.updateInvestorKYC(wallet, true);

    // Finishing
    await expectThrow(this.crowdsale.claimTokens.call({from : wallet}));
  });

  it('claimtokens catch deposit eq to 0', async function () {
     // Adding deal to register
    const bonusWallet = new web3.BigNumber(1000);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    // Updating kyc
    await this.crowdsale.updateInvestorKYC(wallet, true);

    // Finishing
    await increaseTimeTo(this.afterEndTime);    
    let resultFinish = await this.crowdsale.finishCrowdsale();
    assert.equal(resultFinish.logs[0].event, 'CrowdsakeFinished');

    await expectThrow(this.crowdsale.claimTokens.call({from : wallet}));
  });

  it('claimtokens cover main cliff', async function () {
    // Adding deal to register
    const bonusWallet = new web3.BigNumber(1000);

    const mainCliffTime = new web3.BigNumber(30); 
    const mainCliffAmount = new web3.BigNumber(80); 
    const additionalCliffAmount = new web3.BigNumber(10);
    const additionalCliffTime = new web3.BigNumber(40); 

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.assignDepositTimeLock(wallet, mainCliffAmount, mainCliffTime, additionalCliffAmount, additionalCliffTime);
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

    const dateClif = this.afterEndTime + duration.days(10);

    await increaseTimeTo(dateClif);
    await this.crowdsale.claimTokens.call({from : wallet});
  });

  it('claimtokens cover additional cliff', async function () {
    // Adding deal to register
    const bonusWallet = new web3.BigNumber(1000);

    const mainCliffTime = new web3.BigNumber(30);
    const mainCliffAmount = new web3.BigNumber(80); 
    const additionalCliffAmount = new web3.BigNumber(10);
    const additionalCliffTime = new web3.BigNumber(40);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.assignDepositTimeLock(wallet, mainCliffAmount, mainCliffTime, additionalCliffAmount, additionalCliffTime);
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

    const dateClif = this.afterEndTime + duration.days(35);

    await increaseTimeTo(dateClif);
    await this.crowdsale.claimTokens.call({from : wallet});
  });

  it('claimtokens cover main cliff 2', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(
        wallet,
        walletTeam,
        walletAdvisers,
        walletOperating,
        walletReserve,
        walletBounty,
        this.startTime,
        this.endTime,
        softCap,
        hardCap
    );

    const bonusWallet = new web3.BigNumber(1000);

    const mainCliffTime = new web3.BigNumber(30);
    const mainCliffAmount = new web3.BigNumber(80);
    const additionalCliffAmount = new web3.BigNumber(10);
    const additionalCliffTime = new web3.BigNumber(40);

    await increaseTimeTo(this.startTime);
    await this.crowdsaleMock.addAdmin(owner);
    await this.crowdsaleMock.assignDepositTimeLock(wallet, mainCliffAmount, mainCliffTime, additionalCliffAmount, additionalCliffTime);
    await this.crowdsaleMock.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    let result = await this.crowdsaleMock.sendTransaction({ value: 1001, from: investor })
    assert.equal(result.logs[0].event, 'DepositAdded');
    let item = await this.crowdsaleMock.investorsMap.call(investor);
    assert.equal(item[0], wallet);

    await this.crowdsaleMock.updateInvestorKYC(wallet, true);

    await increaseTimeTo(this.afterEndTime);
    let resultFinish = await this.crowdsaleMock.finishCrowdsale();
    assert.equal(resultFinish.logs[0].event, 'CrowdsakeFinished');

    const dateCliff = this.afterEndTime + duration.days(10);

    await this.crowdsaleMock.setMainCliffAmount(wallet, 0);

    await increaseTimeTo(dateCliff);
    await this.crowdsaleMock.claimTokens.call({from : wallet});
  });

  it('claimtokens cover main cliff 3', async function () {
    this.crowdsaleMock = await CrowdsaleMock.new(
        wallet,
        walletTeam,
        walletAdvisers,
        walletOperating,
        walletReserve,
        walletBounty,
        this.startTime,
        this.endTime,
        softCap,
        hardCap
    );

    const bonusWallet = new web3.BigNumber(1000);

    const mainCliffTime = new web3.BigNumber(30);
    const mainCliffAmount = new web3.BigNumber(80);
    const additionalCliffAmount = new web3.BigNumber(10);
    const additionalCliffTime = new web3.BigNumber(40);

    await increaseTimeTo(this.startTime);
    await this.crowdsaleMock.addAdmin(owner);
    await this.crowdsaleMock.assignDepositTimeLock(wallet, mainCliffAmount, mainCliffTime, additionalCliffAmount, additionalCliffTime);
    await this.crowdsaleMock.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    let result = await this.crowdsaleMock.sendTransaction({ value: 1001, from: investor })
    assert.equal(result.logs[0].event, 'DepositAdded');
    let item = await this.crowdsaleMock.investorsMap.call(investor);
    assert.equal(item[0], wallet);

    await this.crowdsaleMock.updateInvestorKYC(wallet, true);

    await increaseTimeTo(this.afterEndTime);
    let resultFinish = await this.crowdsaleMock.finishCrowdsale();
    assert.equal(resultFinish.logs[0].event, 'CrowdsakeFinished');

    const dateCliff = this.afterEndTime + duration.days(10);

    await this.crowdsaleMock.setMainCliffAmount(wallet, 1);
    await this.crowdsaleMock.setDepositTransferred(wallet, 5005);

    await increaseTimeTo(dateCliff);
    await this.crowdsaleMock.claimTokens.call({from : wallet});
  });
});