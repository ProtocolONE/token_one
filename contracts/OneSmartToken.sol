pragma solidity ^0.4.19;

import "./token/MintableToken.sol";


contract OneSmartToken is MintableToken {
  
  string public name = "Protocol ONE";
  string public symbol = "ONE";
  uint8 public decimals = 18;
}
