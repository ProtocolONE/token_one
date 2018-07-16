

import assertJump from './helpers/assertJump';

const Ownable = artifacts.require('../contracts/ownership/Ownable.sol');

contract('Ownable', (accounts) => {
  let ownable;

  beforeEach(async () => {
    ownable = await Ownable.new();
  });

  it('should have an owner', async () => {
    const owner = await ownable.owner();
    assert.isTrue(owner !== 0);
  });

  it('changes owner after transfer', async () => {
    const other = accounts[1];
    await ownable.transferOwnership(other);
    const owner = await ownable.owner();

    assert.isTrue(owner === other);
  });

  it('should prevent non-owners from transfering', async () => {
    const other = accounts[2];
    const owner = await ownable.owner.call();
    assert.isTrue(owner !== other);
    try {
      await ownable.transferOwnership(other, {
        from: other,
      });
      assert.fail('should have thrown before');
    } catch (error) {
      assertJump(error);
    }
  });

  it('should guard ownership against stuck state', async () => {
    const originalOwner = await ownable.owner();
    try {
      await ownable.transferOwnership(null, {
        from: originalOwner,
      });
      assert.fail();
    } catch (error) {
      assertJump(error);
    }
  });
});
