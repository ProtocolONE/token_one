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
  
  event Burn(address indexed burner, uint256 value);
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
  
  /**
   * @dev Burns a specific amount of tokens.
   *
   * @param _who token holder address which the tokens will be burnt
   * @param _value number of tokens to burn
   */
  function burn(address _who, uint256 _value) external onlyManager {
    require(_value <= balances[_who]);
    // no need to require value <= totalSupply, since that would imply the
    // sender's balance is greater than the totalSupply, which *should* be an assertion failure
    
    balances[_who] = balances[_who].sub(_value);
    totalSupply_ = totalSupply_.sub(_value);
    
    emit Burn(_who, _value);
  }
  
  /**
   * @dev Transfer token for a specified address
   * @param _to The address to transfer to.
   * @param _value The amount to be transferred.
   */
  function transfer(address _to, uint256 _value) public whenNotLocked returns (bool) {
    return super.transfer(_to, _value);
  }
  
  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public whenNotLocked returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }
  
  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public whenNotLocked returns (bool) {
    return super.approve(_spender, _value);
  }
  
  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
  function increaseApproval(address _spender, uint _addedValue) public whenNotLocked returns (bool success) {
    return super.increaseApproval(_spender, _addedValue);
  }
  
  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   * approve should be called when allowed[_spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseApproval(address _spender, uint _subtractedValue) public whenNotLocked returns (bool success) {
    return super.decreaseApproval(_spender, _subtractedValue);
  }
}
