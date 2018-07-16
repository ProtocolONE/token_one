# Protocol One ERC-20 Token
[![Build Status](https://travis-ci.org/ProtocolONE/token_one.svg?branch=master)](https://travis-ci.org/ProtocolONE/token_one)
[![Coverage Status](https://img.shields.io/coveralls/github/ProtocolONE/token_one/master.svg?style=flat-square)](https://coveralls.io/github/ProtocolONE/token_one?branch=master)

This project contains the smart contracts that govern the [Protocol One](https://protocol.one/) token.

The official Protocol One token, with the ERC-20 symbol `ONE` is located on ethereum 
and could be resolved by name [protocolone.eth](https://etherscan.io/address/protocolone.eth). Which is currently `Update after deploy`.

## Contracts

Please see the [contracts/](contracts) directory.

## Prerequisites
* node 8+
* npm
* [truffle](http://truffleframework.com/)

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
	* 17% of the total supply for future strategic plans for the created ecosystem
	* 12% of the total supply for the team and SDK developers
	* 8% of the total supply for Protocol One crowdsale campaign
	* 3% of the total supply for professional fees and Bounties
	* 1% of the total supply for bounty program
