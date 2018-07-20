import { advanceBlock } from './helpers/advanceToBlock';
import { increaseTimeTo, duration } from './helpers/increaseTime';
import latestTime from './helpers/latestTime';

const utils = require('./helpers/Utils');

require('chai').use(require('chai-as-promised')).use(require('chai-bignumber')(web3.BigNumber)).should();

const Crowdsale = artifacts.require('../contracts/crowdsale/Crowdsale.sol');

contract('Crowdsale', () => {
  const rate = new web3.BigNumber(1000);
  const softCap = new web3.BigNumber(2000);
  const hardCap = new web3.BigNumber(5000);

  before(async () => {
    // Advance to the next block to correctly read
    // time in the solidity "now" function interpreted by testrpc
    await advanceBlock();
  });

  beforeEach(async function () {
    this.startTime = latestTime() + duration.weeks(1);
    this.endTime = this.startTime + duration.weeks(1);
    this.afterEndTime = this.endTime + duration.seconds(1);

    this.crowdsale = await Crowdsale.new(this.startTime, this.endTime, rate, softCap, hardCap);
  });

  it('should be ended only after end', async function () {
    let ended = await this.crowdsale.hasClosed();
    ended.should.equal(false);
    await increaseTimeTo(this.afterEndTime);
    ended = await this.crowdsale.hasClosed();
    ended.should.equal(true);
  }); 

  it('check rate', async function () {
    let rateFromContract = await this.crowdsale.getRate();
    assert.equal(rateFromContract, 1000);    
  });

  it('check open modifier', async function () {
    await increaseTimeTo(this.startTime);
    await this.crowdsale.setRate(1001);
    let rateFromContract = await this.crowdsale.getRate();
    // Should be changed
    assert.equal(rateFromContract, 1001);    

    await increaseTimeTo(this.afterEndTime);
    try {
      await this.crowdsale.setRate(1002);
    } catch (error) {
      return utils.ensureException(error);
    }

    rateFromContract = await this.crowdsale.getRate();
    assert.equal(rateFromContract, 1001);
  });

});