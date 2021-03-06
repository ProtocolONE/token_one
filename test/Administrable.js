import expectThrow from './helpers/expectThrow';

const Administrable = artifacts.require('../contracts/ownership/Administrable.sol');

contract('Administrable', (accounts) => {
  let admin;

  beforeEach(async () => {
    admin = await Administrable.new();
  });

  it('add admin', async () => {
    await admin.addAdmin(accounts[1]);
    const accAdmin = await admin.admins.call(accounts[1]);
    assert.equal(accAdmin, true);
  });

  it('add admin catch 1', async () => {
    await expectThrow(admin.addAdmin(0));
  });

  it('remove admin catch 1', async () => {
    await expectThrow(admin.removeAdmin(0));
  });

  it('delete admin', async () => {
    await admin.addAdmin(accounts[1]);
    let accAdmin = await admin.admins.call(accounts[1]);
    assert.equal(accAdmin, true);

    await admin.removeAdmin(accounts[1]);
    accAdmin = await admin.admins.call(accounts[1]);
    assert.equal(accAdmin, false);
  });

  it('total admin count', async () => {
    await admin.addAdmin(accounts[1]);
    await admin.addAdmin(accounts[2]);
    await admin.addAdmin(accounts[3]);
    await admin.addAdmin(accounts[4]);
    await admin.addAdmin(accounts[5]);

    let totalAdmins = await admin.totalAdminsMapping.call({from : accounts[0]});
    assert.equal(totalAdmins, 5);
  });
});
