

import expectThrow from './helpers/expectThrow';

const MintableToken = artifacts.require('../contracts/OneSmartToken.sol');

contract('OneSmartToken', (accounts) => {
  let token;

  beforeEach(async () => {
    token = await MintableToken.new(accounts[0]);
  });

  it('token instance create exception', async () => {
    await expectThrow(MintableToken.new(0));
  });

  it('should start with a totalSupply of 0', async () => {
    const totalSupply = await token.totalSupply();

    assert.equal(totalSupply.toNumber(), 0);
  });

  it('should return mintingFinished false after construction', async () => {
    const mintingFinished = await token.mintingFinished();

    assert.equal(mintingFinished, false);
  });

  it('only owner can unlock token', async () => {
    await expectThrow(token.unlock({ from : accounts[1] }));
  });

  it('should mint a given amount of tokens to a given address', async () => {
    const result = await token.mint(accounts[0], 100);
    assert.equal(result.logs[0].event, 'Mint');
    assert.equal(result.logs[0].args.to.valueOf(), accounts[0]);
    assert.equal(result.logs[0].args.amount.valueOf(), 100);
    assert.equal(result.logs[1].event, 'Transfer');
    assert.equal(result.logs[1].args.from.valueOf(), 0x0);

    const balance0 = await token.balanceOf(accounts[0]);
    assert(balance0, 100);

    const totalSupply = await token.totalSupply();
    assert(totalSupply, 100);
  });

  it('should fail to mint after call to finishMinting', async () => {
    await token.finishMinting();
    assert.equal(await token.mintingFinished(), true);
    await expectThrow(token.mint(accounts[0], 100));
  });

  it('should lock token correctly', async () => {
    let result = await token.unlock();
    assert.equal(result.logs[0].event, 'Unlocked');

    result = await token.lock();
    assert.equal(result.logs[0].event, 'Locked');
  });

  it('should fail lock token with exception', async () => {
    await expectThrow(token.lock());
  });

  it('should unlock token correctly', async () => {
    const result = await token.unlock();
    assert.equal(result.logs[0].event, 'Unlocked');
  });

  it('should fail unlock token with exception', async () => {
    const result = await token.unlock();
    assert.equal(result.logs[0].event, 'Unlocked');
    await expectThrow(token.unlock());
  });

  it('should fail with exception to transfer coins', async () => {
    await token.mint(accounts[0], 10);
    await expectThrow(token.transfer(accounts[1], 10));
  });

  it('should transfer coins correctly', async () => {
    const amount = 10;

    await token.mint(accounts[0], amount);

    const accountOneStartingBalance = await token.balanceOf(accounts[0]);
    const accountTwoStartingBalance = await token.balanceOf(accounts[1]);

    let result = await token.unlock();
    assert.equal(result.logs[0].event, 'Unlocked');

    result = await token.transfer(accounts[1], amount);
    assert.equal(result.logs[0].event, 'Transfer');

    const accountOneEndingBalance = await token.balanceOf(accounts[0]);
    const accountTwoEndingBalance = await token.balanceOf(accounts[1]);

    assert.equal(accountOneEndingBalance.toNumber(), accountOneStartingBalance - amount);
    assert.equal(accountTwoEndingBalance.toNumber(), accountTwoStartingBalance + amount);
  });

  it('should burn coins correctly', async () => {
    const amount = 10;
    const burnAmount = 1;

    await token.mint(accounts[0], amount);

    let result = await token.unlock();
    assert.equal(result.logs[0].event, 'Unlocked');

    result = await token.transfer(accounts[0], amount);
    assert.equal(result.logs[0].event, 'Transfer');

    const accountStartingBalance = await token.balanceOf(accounts[0]);

    result = await token.burn(accounts[0], burnAmount);
    assert.equal(result.logs[0].event, 'Burn');

    const accountEndingBalance = await token.balanceOf(accounts[0]);

    assert.equal(accountStartingBalance.toNumber(), amount);
    assert.equal(accountEndingBalance.toNumber(), accountStartingBalance - burnAmount);
  });

  it('burn tokens greater than has on balance', async () => {
    const amount = 10;
    const burnAmount = 11;

    await token.mint(accounts[0], amount);

    let result = await token.unlock();
    assert.equal(result.logs[0].event, 'Unlocked');

    result = await token.transfer(accounts[0], amount);
    assert.equal(result.logs[0].event, 'Transfer');

    await expectThrow(token.burn(accounts[0], burnAmount));
  });

  it('should transfer coins from first account to second account correctly', async () => {
    const amount = 10;

    await token.mint(accounts[0], amount);

    let result = await token.unlock();
    assert.equal(result.logs[0].event, 'Unlocked');

    const accountOneStartingBalance = (await token.balanceOf(accounts[0])).toNumber();
    const accountTwoStartingBalance = (await token.balanceOf(accounts[1])).toNumber();

    result = await token.approve(accounts[0], amount);
    assert.equal(result.logs[0].event, 'Approval');

    result = await token.transferFrom(accounts[0], accounts[1], amount);
    assert.equal(result.logs[0].event, 'Transfer');

    const accountOneEndingBalance = (await token.balanceOf(accounts[0])).toNumber();
    const accountTwoEndingBalance = (await token.balanceOf(accounts[1])).toNumber();

    assert.equal(accountOneEndingBalance, accountOneStartingBalance - amount);
    assert.equal(accountTwoEndingBalance, accountTwoStartingBalance + amount);
  });

  it('approve transfer tokens between accounts with unlock exception', async () => {
    await token.mint(accounts[0], 10);
    await expectThrow(token.approve(accounts[0], 10));
  });

  it('transfer tokens between accounts with not approve exception', async () => {
    await token.mint(accounts[0], 10);
    await expectThrow(token.transferFrom(accounts[0], accounts[1], 10));
  });

  it('transfer tokens between accounts with with amount not allowed on balance exception', async () => {
    const amount = 10;
    const transferAmount = 11;

    await token.mint(accounts[0], amount);
    await token.unlock();
    await token.approve(accounts[0], amount);

    await expectThrow(token.transferFrom(accounts[0], accounts[1], transferAmount));
  });

  it('increase amount to transfer between accounts', async () => {
    const amount = 100;
    const transferAmount = 11;

    await token.mint(accounts[0], amount);

    const accountOneStartingBalance = (await token.balanceOf(accounts[0])).toNumber();
    const accountTwoStartingBalance = (await token.balanceOf(accounts[1])).toNumber();

    let result = await token.unlock();
    assert.equal(result.logs[0].event, 'Unlocked');

    result = await token.approve(accounts[0], 10);
    assert.equal(result.logs[0].event, 'Approval');

    await expectThrow(token.transferFrom(accounts[0], accounts[1], transferAmount));

    result = await token.increaseApproval(accounts[0], 1);
    assert.equal(result.logs[0].event, 'Approval');

    result = await token.transferFrom(accounts[0], accounts[1], transferAmount);
    assert.equal(result.logs[0].event, 'Transfer');

    const accountOneEndingBalance = (await token.balanceOf(accounts[0])).toNumber();
    const accountTwoEndingBalance = (await token.balanceOf(accounts[1])).toNumber();

    assert.equal(accountOneEndingBalance, accountOneStartingBalance - transferAmount);
    assert.equal(accountTwoEndingBalance, accountTwoStartingBalance + transferAmount);
  });

  it('decrease amount to transfer between accounts', async () => {
    const amount = 10;

    await token.mint(accounts[0], amount);
    await token.unlock();
    await token.approve(accounts[0], amount);

    const result = await token.decreaseApproval(accounts[0], 1);
    assert.equal(result.logs[0].event, 'Approval');

    await expectThrow(token.transferFrom(accounts[0], accounts[1], amount));
  });
});
