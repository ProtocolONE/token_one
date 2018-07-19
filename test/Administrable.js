 import expectThrow from './helpers/expectThrow';

const Administrable = artifacts.require('../contracts/ownership/Administrable.sol');

contract('Administrable', (accounts) => {
  let admin;

  beforeEach(async () => {
    admin = await Administrable.new();
  });

  it('add admin', async () => {
    await admin.addAdmin(accounts[1]);
    let accAdmin = await admin.admins.call(accounts[1]);
    assert.equal(accAdmin, true);
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

    let totalAdmins = await admin.totalAdminsMapping();
    assert.equal(totalAdmins, 5);
  });
});
