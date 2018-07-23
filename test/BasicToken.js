import assertJump from './helpers/assertJump';

const BasicTokenMock = artifacts.require('./helpers/BasicTokenMock.sol');

contract('BasicToken', (accounts) => {
  it('should return the correct totalSupply after construction', async () => {
    const token = await BasicTokenMock.new(accounts[0], 100);
    const totalSupply = await token.totalSupply();

    assert.equal(totalSupply, 100);
  });

  it('should return correct balances after transfer', async () => {
    const token = await BasicTokenMock.new(accounts[0], 100);
    await token.transfer(accounts[1], 100);

    const firstAccountBalance = (await token.balanceOf(accounts[0])).toNumber();
    assert.equal(firstAccountBalance, 0);

    const secondAccountBalance = (await token.balanceOf(accounts[1])).toNumber();
    assert.equal(secondAccountBalance, 100);
  });

  it('should throw an error when trying to transfer more than balance', async () => {
    const token = await BasicTokenMock.new(accounts[0], 100);
    try {
      await token.transfer(accounts[1], 101);
      assert.fail('should have thrown before');
    } catch (error) {
      assertJump(error);
    }
  });

  it('should throw an error when trying to transfer to 0x0', async () => {
    const token = await BasicTokenMock.new(accounts[0], 100);
    try {
      await token.transfer(0x0, 100);
      assert.fail('should have thrown before');
    } catch (error) {
      assertJump(error);
    }
  });
});
