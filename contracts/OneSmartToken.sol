pragma solidity ^0.4.19;

import "openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";


contract OneSmartToken is MintableToken {
  
  string public name = "Protocol ONE";
  string public symbol = "ONE";
  uint8 public decimals = 18;
}
