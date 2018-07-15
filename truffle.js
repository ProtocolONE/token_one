require('babel-register');
require('babel-polyfill');

const HDWalletProvider = require('truffle-hdwallet-provider')
const fs = require('fs')

// First read in the secrets.json to get our mnemonic
let secrets;
let mnemonic;
if (fs.existsSync('secrets.json')) {
  secrets = JSON.parse(fs.readFileSync('secrets.json', 'utf8'))
  mnemonic = secrets.mnemonic
} else {
  console.log('No secrets.json found. If you are trying to publish EPM ' +
              'this will fail. Otherwise, you can ignore this message!')
  mnemonic = ''
}

module.exports = {
  networks: {
    development: {
      host: "localhost",
      network_id: "*",
      port: 8555,        
      gas: 4600000,
      gasPrice: 0x01     
    }
  }
}
