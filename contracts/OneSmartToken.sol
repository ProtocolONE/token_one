pragma solidity ^0.4.19;

import "openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";


contract OneSmartToken is MintableToken {
  
  string public name = "Protocol ONE";
  string public symbol = "ONE";
  uint8 public decimals = 18;

  address admin;
  
  event TransfersAllowed();
  
  modifier onlyAdmin {
    require(msg.sender  == admin);
    _;
  }
  
  constructor(address _superAdmin) {
    require(_superAdmin != address(0));
    admin = _superAdmin;
  }
  
  // This state is specific to the token generation event. We disallow
  // to transfer token before exchange listing.
  bool public allowTransfers;
  
  function setAllowTransfers() public onlyAdmin returns (bool) {
    allowTransfers = true;
    TransfersAllowed();
    return true;
  }
  
  function transfer(address recipient, uint256 amount) public returns (bool) {
    require(allowTransfers);
    require(amount > 0);
    
    return super.transfer(recipient, amount);
  }
  
  function transferFrom(address from, address to, uint256 value) public returns (bool) {
    require(allowTransfers);
    require(amount > 0);
    
    return super.transferFrom(from, to, value);
  }
}
