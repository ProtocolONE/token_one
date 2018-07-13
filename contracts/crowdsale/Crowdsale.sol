pragma solidity ^0.4.24;

import "../ownership/Administrable.sol";
import "../math/SafeMath.sol";


/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for crowdsales. They are *not* intended to be modified / overriden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropiate to concatenate
 * behavior.
 */
contract Crowdsale is Administrable {
  using SafeMath for uint256;
 
  uint256 public rate;
  
  // Amount of wei raised
  uint256 public weiRaised;
  
  uint256 public openingTime;
  
  uint256 public closingTime;
  
  uint256 public softCap;
  
  uint256 public hardCap;

  /**
   * @param _rate Number of token units a buyer gets per wei
   * @param _wallet Address where collected funds will be forwarded to
   */
  constructor(uint256 _openingTime, uint256 _closingTime, uint256 _rate, uint256 _softCap, uint256 _hardCap) public {

    require(_openingTime >= block.timestamp);
    require(_closingTime >= _openingTime);
  
    require(_rate > 0);
    require(_softCap > 0);
    require(_hardCap >= _softCap);
    
    openingTime = _openingTime;
    closingTime = _closingTime;
    
    rate = _rate;
    hardCap = _hardCap;
    softCap = _softCap;
  }
  
  /**
  * @dev Reverts if not in crowdsale time range.
  */
  modifier onlyWhileOpen {
    // solium-disable-next-line security/no-block-members
    require(block.timestamp >= openingTime && block.timestamp <= closingTime);
    _;
  }
  
  modifier hardCapNotReached() {
    require(weiRaised.add(msg.value) <= hardCap);
    _;
  }

  /**
   * @return the crowdsale rate
   */
  function getRate() public view returns (uint256) {
    return rate;
  }
  
  /**
   * @dev Set rate of ETH and update token price
   * @param _RateEth current ETH rate
   */
  function setRate(uint256 _RateEth) external onlyWhileOpen onlyOwner {
    rate = _RateEth;
  }
  
  /**
   * @dev Checks whether the cap has been reached.
   * @return Whether the cap was reached
   */
  function hardCapReached() public view returns (bool) {
    return weiRaised >= hardCap;
  }
  
  /**
   * @dev Checks whether the cap has been reached.
   * @return Whether the cap was reached
   */
  function softCapReached() public view returns (bool) {
    return weiRaised >= softCap;
  }
  
  /**
   * @dev Checks whether the period in which the crowdsale is open has already elapsed.
   * @return Whether crowdsale period has elapsed
   */
  function hasClosed() public view returns (bool) {
    // solium-disable-next-line security/no-block-members
    return block.timestamp > closingTime;
  }
}