const utils = require('./helpers/Utils');

const SafeMathMock = artifacts.require('./helpers/SafeMathMock.sol');

contract('SafeMath', (accounts) => {
  let safeMath;

  before(async () => {
    safeMath = await SafeMathMock.new();
  });

  it('multiplies correctly', async () => {
    const a = 5678;
    const b = 1234;
    const mult = await safeMath.multiply(a, b);
    const result = await safeMath.result();
    assert.equal(result, a * b);
  });

  it('adds correctly', async () => {
    const a = 5678;
    const b = 1234;
    const add = await safeMath.add(a, b);
    const result = await safeMath.result();

    assert.equal(result, a + b);
  });

  it('subtracts correctly', async () => {
    const a = 5678;
    const b = 1234;
    const subtract = await safeMath.subtract(a, b);
    const result = await safeMath.result();

    assert.equal(result, a - b);
  });

  it('should throw an error if subtraction result would be negative', async () => {
    const a = 1234;
    const b = 5678;
    try {
      const subtract = await safeMath.subtract(a, b);
      assert.fail('should have thrown before');
    } catch (error) {
      return utils.ensureException(error);
    }
  });

  it('should throw an error on addition overflow', async () => {
    const a = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    const b = 1;
    try {
      const add = await safeMath.add(a, b);
      assert.fail('should have thrown before');
    } catch (error) {
      return utils.ensureException(error);
    }
  });

  it('should throw an error on multiplication overflow', async () => {
    const a = 115792089237316195423570985008687907853269984665640564039457584007913129639933;
    const b = 2;
    try {
      const multiply = await safeMath.multiply(a, b);
      assert.fail('should have thrown before');
    } catch (error) {
      return utils.ensureException(error);
    }
  });

  it('should div correctly', async () => {
    const a = 5678;
    const b = 1234;
    const div = await safeMath.div(a, b);
    const result = await safeMath.result();

    assert.equal(result, Math.floor(a / b));
  });

  it('should throw an error on division by 0', async () => {
    const a = 100;
    const b = 0;

    try {
      const subtract = await safeMath.div(a, b);
      assert.fail('should have thrown before');
    } catch (error) {
      return utils.ensureException(error);
    }
  });
});
