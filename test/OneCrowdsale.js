import ether from './helpers/ether'
import {advanceBlock} from './helpers/advanceToBlock'
import {increaseTimeTo, duration} from './helpers/increaseTime'
import latestTime from './helpers/latestTime'
import EVMThrow from './helpers/EVMThrow'

const utils = require('./helpers/Utils');

const BigNumber = web3.BigNumber

const should = require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(BigNumber))
    .should()

const OneCrowdsale = artifacts.require('../contracts/OneCrowdsale.sol')
const OneSmartToken = artifacts.require('../contracts/OneSmartToken.sol')
const RefVault = artifacts.require('../contracts/crowdsale/RefundVault.sol')

contract('OneCrowdsale', function([_, investor, owner, wallet, walletTeam, walletAdvisers, 
    walletFounders, walletMarketing, walletReserve]) {

    const value = ether(1)

    before(async function() {
        //Advance to the next block to correctly read time in the solidity "now" function interpreted by testrpc
        await advanceBlock()
    })
    beforeEach(async function() {
        this.startTime = latestTime() + duration.weeks(1);
        this.endTime = this.startTime + duration.weeks(1)
        this.afterEndTime = this.endTime + duration.seconds(1)

        this.token = await OneSmartToken.new({from: owner});
        this.refundVault = await RefundVault.new(wallet, this.token.address,{from: owner});

        this.crowdsale = await OneCrowdsale.new(this.startTime,
            this.endTime,
            wallet,
            walletTeam,
            walletAdvisers,
            walletFounders,
            walletMarketing,
            walletReserve,
            this.token.address,
            this.refundVault.address,
            {
                from: owner
            })
    })

    describe('Kyc operations', function() {

        it('Buy token and register investor', async function() {

            await increaseTimeTo(this.startTime)
            await this.crowdsale.sendTransaction({
                value: value,
                from: investor
            })

            let deal = this.crowdsale.investorsMap(investor)

            assert(deal._kycPassed == true, "wrong kyc");
        }) 

        it('Buy token, register investor and update kyc', async function() {

            await increaseTimeTo(this.startTime)
            await this.crowdsale.sendTransaction({
                value: value,
                from: investor
            })

            await this.crowdsale.sendTransaction({
                value: value,
                from: investor
            })

            await this.crowdsale.updateInvestorKYC({
                value: true,
                from: investor
            })

            let deal = this.crowdsale.investorsMap(investor)

            assert(deal._kycPassed == false, "wrong kyc");
        })        
    })

    describe('Token destroy', function() {

        it('should not allow destroy before after finalize', async function() {

            await increaseTimeTo(this.startTime)
            await this.crowdsale.sendTransaction({
                value: value,
                from: investor
            })

            try {
                await this.token.destroy(investor, 20, {from: investor});
            } catch (error) {
                return utils.ensureException(error);
            }
        })

        it('should allow destroy after finalize', async function() {

            await increaseTimeTo(this.startTime)
            await this.crowdsale.sendTransaction({
                value: value,
                from: investor
            })

            await increaseTimeTo(this.afterEndTime)
            await this.crowdsale.finalize({
                from: owner
            })

            await this.token.destroy(investor, 20, {from: investor});
        })
    })
})