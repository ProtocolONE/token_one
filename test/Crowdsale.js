import ether from './helpers/ether';
import { advanceBlock } from './helpers/advanceToBlock';
import { increaseTimeTo, duration } from './helpers/increaseTime';
import latestTime from './helpers/latestTime';
import EVMThrow from './helpers/EVMThrow';
import expectThrow from './helpers/expectThrow';

const utils = require('./helpers/Utils');

const BigNumber = web3.BigNumber;
const should = require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const Crowdsale = artifacts.require('../contracts/crowdsale/Crowdsale.sol');
const SmartToken = artifacts.require('OneSmartToken');

contract('Crowdsale', ([_, investor, wallet, purchaser]) => {
  const rate = new BigNumber(1000);
  const softCap = new BigNumber(2000);
  const hardCap = new BigNumber(5000);

  const value = ether(42);

  before(async () => {
    // Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
    await advanceBlock();
  });

  beforeEach(async function () {
    this.startTime = latestTime() + duration.weeks(1);
    this.endTime = this.startTime + duration.weeks(1);
    this.afterEndTime = this.endTime + duration.seconds(1);

    this.crowdsale = await Crowdsale.new(this.startTime, this.endTime, rate, softCap, hardCap);
  });

  it('should be ended only after end', async function () {
    let ended = await this.crowdsale.hasClosed.call({from : investor});
    ended.should.equal(false);
    await increaseTimeTo(this.afterEndTime);
    ended = await this.crowdsale.hasClosed.call({from : investor});;
    ended.should.equal(true);
  });

  it('check rate', async function () {
    let rateFromContract = await this.crowdsale.getRate.call({from : investor});
    assert.equal(rateFromContract, 1000);
  });

  it('check open modifier', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.setRate(1001);
    let rateFromContract = await this.crowdsale.getRate.call({from : investor});
    // Should be changed
    assert.equal(rateFromContract, 1001);

    await increaseTimeTo(this.afterEndTime);
    try {
      await this.crowdsale.setRate(1002);
    } catch (error) {
      return utils.ensureException(error);
    }

    rateFromContract = await this.crowdsale.getRate.call({from : investor});
    assert.equal(rateFromContract, 1001);
  });

  it('constructor check 1', async function () {
    let decrBlock = this.startTime - duration.years(1);
    await expectThrow(Crowdsale.new(decrBlock, this.endTime, rate, softCap, hardCap));
  });

  it('constructor check 2', async function () {
    await expectThrow(Crowdsale.new(this.endTime, this.startTime, rate, softCap, hardCap));
  });

  it('constructor check 3', async function () {
    await expectThrow(Crowdsale.new(this.startTime, this.endTime, this.rate, hardCap, softCap));
  });

  it('hardcap check', async function () {
    let res = await this.crowdsale.hardCapReached.call();
    assert.equal(res, false);
  });

  it('soft check', async function () {
    let res = await this.crowdsale.softCapReached.call();
    assert.equal(res, false);
  });

});
