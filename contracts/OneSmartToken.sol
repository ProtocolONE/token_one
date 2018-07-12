pragma solidity ^0.4.19;

import "./math/SafeMath.sol";
import "./token/MintableToken.sol";


contract OneSmartToken is MintableToken {
  using SafeMath for uint256;
  
  string public name = "ProtocolOne";
  string public symbol = "ONE";
  uint8 public decimals = 18;

  // This state is specific to the token generation event. We disallow
  // to transfer token before exchange listing.
  bool public locked = true;
  address manager;
  
  modifier whenNotLocked() {
    require(!locked);
    _;
  }
  
  modifier whenLocked() {
    require(locked);
    _;
  }
  
  modifier onlyManager {
    require(msg.sender  == manager);
    _;
  }
  
  event Unlocked();
  event Locked();
  
  constructor(address _manager) public {
    require(_manager != address(0));
    manager = _manager;
  }
  
  function unlock() public onlyManager whenLocked {
    locked = false;
    emit Unlocked();
  }
  
  function lock() public onlyManager whenNotLocked {
    locked = true;
    emit Unlocked();
  }
  
  function transfer(address recipient, uint256 amount) public whenNotLocked returns (bool) {
    return super.transfer(recipient, amount);
  }
  
  function transferFrom(address from, address to, uint256 value) public whenNotLocked returns (bool) {
    return super.transferFrom(from, to, value);
  }
  function approve(address _spender, uint256 _value) public whenNotLocked returns (bool) {
    return super.approve(_spender, _value);
  }
  
  function increaseApproval(address _spender, uint _addedValue) public whenNotLocked returns (bool success) {
    return super.increaseApproval(_spender, _addedValue);
  }
  
  function decreaseApproval(address _spender, uint _subtractedValue) public whenNotLocked returns (bool success) {
    return super.decreaseApproval(_spender, _subtractedValue);
  }
}
