import ether from './helpers/ether';
import { advanceBlock } from './helpers/advanceToBlock';
import { increaseTimeTo, duration } from './helpers/increaseTime';
import latestTime from './helpers/latestTime';
import EVMThrow from './helpers/EVMThrow';

const utils = require('./helpers/Utils');

const BigNumber = web3.BigNumber;
const should = require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const Crowdsale = artifacts.require('./helpers/PreSaleCrowdsaleMock.sol');

contract('PreSaleCrowdsale', ([owner, investor, wallet, bonusWallet, _]) => {
  const rate = new BigNumber(1000);
  const softCap = new BigNumber(2000);
  const hardCap = new BigNumber(5000);

  const bonusShare = new BigNumber(10);
  const weiMinAmount = new BigNumber(1000);
  const bonusRate =  new BigNumber(1000);

  const tokens = new BigNumber(1000);

  const invId = "somedInvoiceId";

  const value = ether(42);

  before(async () => {
    // Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
    await advanceBlock();
  });

  beforeEach(async function () {
    this.startTime = latestTime() + duration.weeks(1);
    this.endTime = this.startTime + duration.weeks(1);
    this.afterEndTime = this.endTime + duration.seconds(1);
    this.bonusRateTime = this.startTime + duration.minutes(1);

    this.crowdsale = await Crowdsale.new(this.startTime, this.endTime, rate, softCap, hardCap);
  });

  it('kyc update', async function () {
    await this.crowdsale.updateInvestorKYC(investor, true);
    let flag = await this.crowdsale.kykPassed.call(investor);
    assert.equal(flag, true);
  });

  it('add deal', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);
    let investorDescription = await this.crowdsale.investorsMap.call(investor);
    assert.equal(investorDescription[0], wallet);    
  });

  it('delete deal', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);

    // Adding
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    // Deleting
    await this.crowdsale.deletePreSaleDeal(investor);
    let investorDescription = await this.crowdsale.investorsMap(investor);
    assert.equal(investorDescription[0], 0);
  });

  it('add invoice', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdateInvoice(investor, tokens, invId);

    let tokenAdded = await this.crowdsale.invoicesMap.call(investor);
    assert.equal(tokenAdded, 1000);
  });

  it('delete invoice', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);

    // Add invoice
    await this.crowdsale.addUpdateInvoice(investor, tokens, invId);
    let tokenAdded = await this.crowdsale.invoicesMap.call(investor);
    assert.equal(tokenAdded, 1000);

    // Delete invoice
    await this.crowdsale.deleteInvoice(investor);
    let tokenDel = await this.crowdsale.invoicesMap.call(investor);
    assert.equal(tokenDel, 0);
  }); 

});