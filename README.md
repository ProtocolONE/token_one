# token_one

## Contracts

Please see the [contracts/](contracts) directory.

## Getting started 

First install truffle and initialize your project with `npm install`.

```sh
npm install -g truffle
npm install -g ganache-cli
```

To use test network start ganache-cli in console with params like this
ganache-cli.cmd -p 8555 -g 1 -l 10000000000000

After this start truffle in another console
truffle console

You would be switched to development network. Now you are able to deploy contracts.

## The Crowdsale Specification
* ONE token is ERC-20 compliant.
* Token allocation:
	* 59% of the total number of ONE tokens will be allocated to contributors during the token sale.
	* 12% of the total number of ONE tokens will be allocated to the team and SDK developers.
	* 15% of the total number of ONE tokens will be allocated to Protocol One founders.
	* 3% of the total number of ONE tokens will be allocated to professional fees and bounties.
	* 10% of the total number of ONE tokens will be allocated to Protocol One, and as a reserve for the company to be used for future strategic plans for the created ecosystem.
