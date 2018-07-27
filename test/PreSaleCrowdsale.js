import ether from './helpers/ether';
import { advanceBlock } from './helpers/advanceToBlock';
import { increaseTimeTo, duration } from './helpers/increaseTime';
import latestTime from './helpers/latestTime';
import expectThrow from './helpers/expectThrow';

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

  it('updateInvestorKYC exception 0 waller', async function () {
    await expectThrow(this.crowdsale.updateInvestorKYC(0, true));
  });

  it('updateInvestorKYC exception with kyk passed false', async function () {
    await this.crowdsale.updateInvestorKYC(investor, true);
    await expectThrow(this.crowdsale.updateInvestorKYC(investor, true));
  });

  it('addUpdatePreSaleDeal exception with 0 incomeWallet', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.addUpdatePreSaleDeal(0, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare));
  });

  it('addUpdatePreSaleDeal exception with 0 wallet', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.addUpdatePreSaleDeal(investor, 0, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare));
  });

  it('addUpdatePreSaleDeal exception with 0 weiMinAmount', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, 0, bonusRate, this.bonusRateTime, bonusShare));
  });

  it('addUpdatePreSaleDeal exception with 0 weiMinAmount', async function () {
    let bonusRateTime = this.startTime - duration.minutes(10);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, bonusRateTime, bonusShare));
  });

  it('addUpdatePreSaleDeal exception with bonusShare greater than 100', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, 111));
  });

  it('addUpdatePreSaleDeal exception with 0 bonusWallet', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.addUpdatePreSaleDeal(investor, wallet, 0, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare));
  });

  it('addUpdatePreSaleDeal bonusRate is 0', async function () {
    let bonusRateTime = this.startTime - duration.minutes(10);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, 0, bonusRateTime, bonusShare);

    let investorDescription = await this.crowdsale.investorsMap.call(investor);
    assert.equal(investorDescription[0], wallet);
  });

  it('addUpdatePreSaleDeal bonusShare is 0', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, 0);

    let investorDescription = await this.crowdsale.investorsMap.call(investor);
    assert.equal(investorDescription[0], wallet);
  });

  it('addUpdatePreSaleDeal create new investor', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    const log = await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    assert.equal(log.logs[0].event, 'InvestorAdded');
  });

  it('addUpdatePreSaleDeal update investor', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    const log = await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);
    assert.equal(log.logs[0].event, 'InvestorUpdated');
  });

  it('deletePreSaleDeal exception with 0 wallet', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    await this.crowdsale.setZeroAddressToInvestorWallet(investor);

    await expectThrow(this.crowdsale.deletePreSaleDeal(investor));
  });

  it('addUpdateInvoice exception with 0 wallet', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.addUpdateInvoice(0, tokens, invId));
  });

  it('addUpdateInvoice exception with 0 tokens', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await expectThrow(this.crowdsale.addUpdateInvoice(investor, 0, invId));
  });

  it('addUpdateInvoice update invoice', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    let log = await this.crowdsale.addUpdateInvoice(investor, tokens, invId);

    assert.equal(log.logs[0].event, 'InvoiceAdded');

    log = await this.crowdsale.addUpdateInvoice(investor, tokens, invId);

    assert.equal(log.logs[0].event, 'InvoiceUpdated');
  });

  it('deleteInvoice exception with 0 wallet', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);

    await this.crowdsale.addUpdateInvoice(investor, tokens, invId);
    await this.crowdsale.invoicesMap.call(investor);

    await expectThrow(this.crowdsale.deleteInvoice(0));
  });

  it('deleteInvoice exception with 0 wallet', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);

    await this.crowdsale.addUpdateInvoice(investor, tokens, invId);
    await this.crowdsale.invoicesMap.call(investor);

    await this.crowdsale.deleteInvoice(investor);
    await expectThrow(this.crowdsale.deleteInvoice(investor));
  });

  it('deletePreSaleDeal investors map skip index', async function () {
    const investorTwo = new web3.BigNumber(1000);
    const walletTwo = new web3.BigNumber(1000);
    const walletThree = new web3.BigNumber(1000);
    const investorThree = new web3.BigNumber(1000);

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdatePreSaleDeal(investor, wallet, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);
    await this.crowdsale.addUpdatePreSaleDeal(investorTwo, walletTwo, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);
    await this.crowdsale.addUpdatePreSaleDeal(investorThree, walletThree, bonusWallet, weiMinAmount, bonusRate, this.bonusRateTime, bonusShare);

    const log = await this.crowdsale.deletePreSaleDeal(investorThree);

    assert.equal(log.logs[0].event, 'DeletePreSaleDealInvestorsMapKeySkipped');
    assert.equal(log.logs[1].event, 'InvestorDeleted');
  });

  it('deleteInvoice invoice map skip index', async function () {
    const investorTwo = new web3.BigNumber(1000);
    const investorTwoId = '3CB928E14AA3DA54C1ECC0E5FE6EAEA9';
    const investorThree = new web3.BigNumber(1000);
    const investorThreeId = '999064E4C374B20168DE09B94692E4DA';

    await increaseTimeTo(this.startTime);
    await this.crowdsale.addAdmin(owner);
    await this.crowdsale.addUpdateInvoice(investor, tokens, invId);
    await this.crowdsale.addUpdateInvoice(investorTwo, tokens, investorTwoId);
    await this.crowdsale.addUpdateInvoice(investorThree, tokens, investorThreeId);

    const log = await this.crowdsale.deleteInvoice(investorThree);

    assert.equal(log.logs[0].event, 'DeleteInvoiceInvoiceMapKeysSkipped');
    assert.equal(log.logs[1].event, 'InvoiceDeleted');
  });
});