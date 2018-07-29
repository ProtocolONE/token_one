import expectThrow from './helpers/expectThrow';

const MintableToken = artifacts.require('../contracts/Tokens/MintableToken.sol');

contract('Mintable', (accounts) => {
  let token;

  beforeEach(async () => {
    token = await MintableToken.new();
  });

  it('should start with a totalSupply of 0', async () => {
    const totalSupply = await token.totalSupply.call();

    assert.equal(totalSupply, 0);
  });

  it('should return mintingFinished false after construction', async () => {
    const mintingFinished = await token.mintingFinished();

    assert.equal(mintingFinished, false);
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
});
