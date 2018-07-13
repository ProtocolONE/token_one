pragma solidity ^0.4.19;

import "./crowdsale/PreSaleCrowdsale.sol";
import "./math/SafeMath.sol";
import "./OneSmartToken.sol";
/*
Чек лист:
- можно возвращать если не пройден кик
- дочинить депозиты
- везде добавить события
- добавить вестинг на время для инвесторов
- добавить вестинг на команду
*/


/**
* In 2018 and in real world a huge amount of conditions required to success processing
* private round investments.
*
* We do not want to
* 1. Do any kind of non blockchain related investors cabinets
* 2. Do any kind of manual operations for wei/ONE token distribution like manual
*    charge or refund or something like this
* 3. Promise "honestly" to not spend team/advisers or any kind of other tokens. All
*    limitations for all members should be in smart contract.
* 4. Be unclear for banks. KYC compliance should be integrated to smart contract.
*/
contract OneCrowdsale is PreSaleCrowdsale {
  using SafeMath for uint256;
  
  OneSmartToken public ONE = new OneSmartToken(this);
  /***********************************************************************/
  /**                              Constants
  /***********************************************************************/
  
  // ONE to ETH base rate
  uint256 public constant EXCHANGE_RATE = 500;
  
  // Minimal length of invoice id for fiat/BTC payments
  uint256 public constant MIN_INVOICE_LENGTH = 5;
  
  // Share amount in ETC for marketing purposes during campaign
  uint256 public constant WALLET_MARKETING_SHARE = 10;

  struct DealDeposit{
    address investorWallet;
    address bonusWallet;
    uint256 depositedETH;
    uint256 depositedTokens;
    uint256 depositedBonusTokens;
    uint256 releaseTime;
  }
  
  event Finalized();
 
  /***********************************************************************/
  /**                              Members
  /***********************************************************************/
  bool public isFinalized = false;
  
  uint256 constant teamPart = 12; // 12% of the total supply for the team and SDK developers
  uint256 constant advisersPart = 3; // 3% of the total supply for professional fees and Bounties
  uint256 constant foundersPart = 15; // 15% of the total supply for Protocol One founders
  uint256 constant reservePart = 10; // 10% of the total supply for future strategic plans for the created ecosystem
  uint256 constant icoPart = 59; // 59% of total supply for public and private offers

// wallets address for 41% of ONE allocation
  address public walletTeam; //
  address public walletAdvisers; //
  address public walletFounders; //
  address public walletReserve; //

  mapping(address => DealDeposit) public depositMap;
  
  /**
  * @param _hardCap Max amount of wei to be contributed
  */
  constructor(
    address _wallet,
    address _walletTeam,
    address _walletAdvisers,
    address _walletFounders,
    address _walletReserve,
    uint256 _openingTime,
    uint256 _closingTime,
    uint256 _softCap,
    uint256 _hardCap
  )
    public
    Crowdsale(_openingTime, _closingTime, EXCHANGE_RATE, _softCap, _hardCap, _wallet)
  {
    require(_walletTeam != address(0));
    require(_walletAdvisers != address(0));
    require(_walletFounders != address(0));
    require(_walletReserve != address(0));
    
    walletTeam = _walletTeam;
    walletAdvisers = _walletAdvisers;
    walletFounders = _walletFounders;
    walletReserve = _walletReserve;
  }
  
  /***********************************************************************/
  /**                    Public Methods
  /***********************************************************************/
  
  /**
   * @dev fallback function ***DO NOT OVERRIDE***
   */
  function () external payable {
    buyTokens(msg.sender);
  }
  
  /**
   * @param _beneficiary Address performing the token purchase
   */
  function buyTokens(address _beneficiary)
    public payable onlyWhitelisted onlyNotCompleted onlyWhileOpen hardCapNotReached
  {
    uint256 weiAmount = msg.value;
    
    PreSaleConditions storage investorDeal = investorsMap[_beneficiary];
    require(investorDeal.weiMinAmount <= weiAmount);
    
    // calculate token amount to be created based on fixed rate
    uint256 baseDealTokens = weiAmount.mul(rate);
    
    // get investor bonus rate based on current day from ICO start and personal deal rate
    uint256 bonusTokens = 0;
    uint256 bonusRate = getBonusRate(investorDeal.incomeWallet);
    if (bonusRate > 0) {
      
      bonusTokens = baseDealTokens.mul(bonusRate).div(100);
      // calculate bonus part in tokens
      uint256 bonusSharePart = bonusTokens.mul(investorDeal.bonusShare).div(100);
      uint256 baseDealBonus = bonusTokens.sub(bonusSharePart);
  
      baseDealTokens.add(baseDealBonus);
      bonusTokens = bonusSharePart;
    }
  
    weiRaised = weiRaised.add(weiAmount);
    
    addDeposit(
      _beneficiary,
      investorDeal.incomeWallet,
      investorDeal.bonusWallet,
      weiAmount,
      baseDealTokens,
      bonusTokens,
      investorDeal.releaseTime
    );

    investorsMap[_beneficiary].completed = true;
    forwardFunds();
  }
  
  function addDeposit(
    address _incomeWallet,
    address _wallet,
    address _bonusWaller,
    uint256 _wei,
    uint256 _tokens,
    uint256 _bonusTokens,
    uint256 _releaseTime
  )
    internal
    onlyOwner
  {
    require(_incomeWallet != address(0));
    require(_wallet != address(0));
    require(_tokens > 0);
    
    depositMap[_incomeWallet].investorWallet = _wallet;
    depositMap[_incomeWallet].bonusWallet = _bonusWaller;
    depositMap[_incomeWallet].depositedETH.add(_wei);
    depositMap[_incomeWallet].depositedTokens.add(_tokens);
    depositMap[_incomeWallet].depositedBonusTokens.add(_bonusTokens);
    depositMap[_incomeWallet].releaseTime = _releaseTime;
  
    ONE.mint(wallet, _tokens.add(_bonusTokens)); //UNDONE
  }
  
  /***********************************************************************/
  /**                              Public Methods
  /***********************************************************************/
  
  function lockTokens() public onlyOwner {
    ONE.lock();
  }
  
  function unlockTokens() public onlyOwner {
    ONE.unlock();
  }
  
  function claimTokens() public onlyKYCPassed {
    address investor = msg.sender;
  
    require(depositMap[investor].releaseTime > now);
    require(depositMap[investor].depositedTokens > 0);
  
    uint256 depositedToken = depositMap[investor].depositedTokens;
    address investorWallet = depositMap[investor].investorWallet;
    
    depositMap[investor].depositedTokens = 0;
    ONE.transfer(investorWallet, depositedToken);
  
    uint256 depositedBonusTokens = depositMap[investor].depositedBonusTokens;
    if (depositedBonusTokens > 0) {
      address bonusWallet = depositMap[investor].bonusWallet;
      depositMap[investor].depositedBonusTokens = 0;
  
      ONE.transfer(bonusWallet, depositedBonusTokens);
    }
    
  
    /*
    investorsMapKeys[index] = investorsMapKeys[investorsMapKeys.length - 1];
    delete investorsMapKeys[investorsMapKeys.length - 1];
    investorsMapKeys.length--;
    */
    //wallet.transfer(depositedETHValue);
  }
  
  /**
  * @return the rate in ONE per 1 ETH.
  */
  function getRate() public view returns (uint256) {
    //UNDONE final rate table
    if (now < (openingTime.add(1 days))) {return 1000;}
    if (now < (openingTime.add(30 days))) {return 550;}
    
    return rate;
  }
  
  function getBonusRate(address _beneficiary) internal view returns (uint256) {
    uint256 bonusRateTime =  investorsMap[_beneficiary].bonusRateTime;
    uint256 bonusRate = investorsMap[_beneficiary].bonusRate;
    
    if (bonusRateTime >= now && bonusRate > 0) {
      return bonusRate;
    }
    
    return 0;
  }
  
  /***********************************************************************/
  /**                              External Methods
  /***********************************************************************/

  
  /***********************************************************************/
  /**                         Internals
  /***********************************************************************/
  
  /**
   * @dev Determines how ETH is stored/forwarded on purchases.
   */
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }
  
  /**
  * @dev Must be called after crowdsale ends, to do some extra finalization
  * work. Calls the contract's finalization function.
  */
  function finishCrowdsale() onlyOwner public {
    require(!isFinalized);
    require(hasClosed()); //UNDONE We need right check for hardcap or time not only time
  
    //TODO  bonuses for the pre crowdsale invoice based payments:
    for (uint256 i = 0; i < invoiceMapKeys.length; i++) {
      address key = invoiceMapKeys[i];
      address wallet = invoicesMap[key].wallet;
      uint256 tokens = invoicesMap[key].tokens;
      uint256 releaseTime = invoicesMap[key].releaseTime;
    
      addDeposit(wallet, wallet, address(0), 0, tokens, 0, releaseTime);
    }
  
    uint256 newTotalSupply = ONE.totalSupply().mul(100).div(icoPart);
  
    ONE.mint(walletTeam, newTotalSupply.mul(teamPart).div(100));
    ONE.mint(walletAdvisers, newTotalSupply.mul(advisersPart).div(100));
    ONE.mint(walletFounders, newTotalSupply.mul(foundersPart).div(100));
    ONE.mint(walletReserve, newTotalSupply.mul(reservePart).div(100));
    
    emit Finalized();
    
    isFinalized = true;
  }
}
