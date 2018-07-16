# Protocol One ERC-20 Token
This project contains the smart contracts that govern the [Protocol One](https://protocol.one/) token.

The official Protocol One token, with the ERC-20 symbol `ONE` is located on ethereum 
and could be resolved by name [protocolone.eth](https://etherscan.io/address/protocolone.eth). Which is currently `Update after deploy`.

## Contracts

Please see the [contracts/](contracts) directory.

## Prerequisites
* node 8+
* npm
* [truffle](http://truffleframework.com/)
* [geth](https://github.com/ethereum/go-ethereum/wiki/Installation-Instructions-for-Mac) to use as CLI ethereum wallet that truffle can manipulate.

After installing, run `geth account new` to create an account on your node.

## Getting started 

First install truffle and initialize your project with `npm install`.

```sh
npm install 
npm install -g truffle
```

Then in another console
```sh
truffle test
```

## The Crowdsale Specification
* ONE token is ERC-20 compliant.
* Token allocation:
	* 59% of the total number of ONE tokens will be allocated to contributors during the token sale.
	* 12% of the total number of ONE tokens will be allocated to the team and SDK developers.
	* 15% of the total number of ONE tokens will be allocated to Protocol One founders.
	* 3% of the total number of ONE tokens will be allocated to professional fees and bounties.
	* 10% of the total number of ONE tokens will be allocated to Protocol One, and as a reserve for the company to be used for future strategic plans for the created ecosystem.
