pragma solidity ^0.4.19;

import "./crowdsale/PreSaleCrowdsale.sol";
import "./math/SafeMath.sol";
import "./OneSmartToken.sol";

/*
Чек лист:
- в депозитах мы должны работать с кошельком получателя (не платильщика как сейчас)
- добавить вестинг на команду - перечисляется на кошелек по расписанию.
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
  
  // ONE to ETH base rate
  uint256 public constant EXCHANGE_RATE = 500;
  
  // Minimal length of invoice id for fiat/BTC payments
  uint256 public constant MIN_INVOICE_LENGTH = 5;

  struct DealDeposit{
    address investorWallet;
    address bonusWallet;
    uint256 depositedETH;
    uint256 depositedTokens;
    uint256 depositedBonusTokens;
    uint256 transferred;
  }
  
  struct DepositTimeLock {
    uint256 mainCliffAmount;
    uint256 mainCliffTime;
    uint256 additionalCliffTime;
    uint256 additionalCliffAmount;
  }
  
  /***********************************************************************/
  /**                              Events
  /***********************************************************************/

  event DepositAdded(
    address indexed beneficiary,
    address indexed bonusBeneficiary,
    uint256 value,
    uint256 amount,
    uint256 bonusAmount
  );
  
  event DepositTimeLockAssigned(
    address indexed _wallet,
    uint256 _mainCliffAmount,
    uint256 _mainCliffTime,
    uint256 _additionalCliffAmount,
    uint256 _additionalCliffTime
  );
  
  event DepositTimeLockDeleted(address indexed _wallet);
  
  event RefundedDeposit(address indexed beneficiary, uint256 value, uint256 amount);
  event TokenClaimed(address indexed _wallet, uint256 value);
  
  /**
   * Event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param bonusBeneficiary who got the bonus tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   * @param bonusAmount amount of bonus tokens purchased
   */
  event TokenPurchased(
    address indexed purchaser,
    address indexed beneficiary,
    address indexed bonusBeneficiary,
    uint256 value,
    uint256 amount,
    uint256 bonusAmount
  );
  
  event CrowdsakeFinished();
  event TokenLocked();
  event TokenUnlocked();
  
  /***********************************************************************/
  /**                              Members
  /***********************************************************************/
  bool public isFinalized = false;
  
  uint256 constant teamPart = 12; // 12% of the total supply for the team and SDK developers
  uint256 constant advisersPart = 3; // 3% of the total supply for professional fees and Bounties
  uint256 constant foundersPart = 15; // 15% of the total supply for Protocol One founders
  uint256 constant reservePart = 10; // 10% of the total supply for future strategic plans for the created ecosystem
  uint256 constant icoPart = 59; // 59% of total supply for public and private offers

  address public wallet; // Address where funds are collected
  address public walletTeam;
  address public walletAdvisers;
  address public walletFounders;
  address public walletReserve;
  
  address[] public depositMapKeys;
  mapping(address => DealDeposit) public depositMap;
  mapping(address => DepositTimeLock) public depositTimeLockMap;
  
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
    Crowdsale(_openingTime, _closingTime, EXCHANGE_RATE, _softCap, _hardCap)
  {
    require(_wallet != address(0));
    require(_walletTeam != address(0));
    require(_walletAdvisers != address(0));
    require(_walletFounders != address(0));
    require(_walletReserve != address(0));
    
    wallet = _wallet;
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
    public payable onlyWhitelisted onlyWhileOpen hardCapNotReached
  {
    uint256 weiAmount = msg.value;
    
    PreSaleConditions storage investorDeal = investorsMap[_beneficiary];
  
    require(investorDeal.investorWallet != address(0));
    require(investorDeal.weiMinAmount <= weiAmount);
    require(investorDeal.completed == false);
    
    // calculate token amount to be created based on fixed rate
    uint256 baseDealTokens = weiAmount.mul(rate);
    
    // get investor bonus rate based on current day from ICO start and personal deal rate
    uint256 bonusTokens = 0;
    uint256 bonusRate = getBonusRate(_beneficiary);
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
      investorDeal.investorWallet,
      investorDeal.bonusWallet,
      weiAmount,
      baseDealTokens,
      bonusTokens
    );
  
    investorDeal.completed = true;
    forwardFunds();
    
    emit TokenPurchased(_beneficiary, investorDeal.investorWallet, investorDeal.bonusWallet, weiAmount, baseDealTokens, bonusTokens);
  }
  
  /**
   * @dev Allow managers to lock tokens distribution while campaign not ended.
   */
  function lockTokens() external onlyOwner {
    ONE.lock();
    
    emit TokenLocked();
  }
  
  /**
   * @dev Allow managers to unlock tokens distribution while campaign not ended.
   */
  function unlockTokens() external onlyOwner {
    ONE.unlock();
    
    emit TokenUnlocked();
  }

  /**
   * @dev Add internal deposit record before actual token distribution.
   *
   * @param _incomeWallet who paid for the tokens
   * @param _wallet who got the tokens
   * @param _bonusWaller who got the bonus tokens
   * @param _wei weis paid for purchase
   * @param _tokens amount of tokens purchased
   * @param _bonusTokens amount of bonus tokens purchased
   */
  function addDeposit(
    address _incomeWallet,
    address _wallet,
    address _bonusWallet,
    uint256 _wei,
    uint256 _tokens,
    uint256 _bonusTokens
  )
    internal
  {
    require(_incomeWallet != address(0));
    require(_wallet != address(0));
    require(_tokens > 0);
    
    DealDeposit storage deposit = depositMap[_incomeWallet];
    if (deposit.investorWallet == address(0)) {
      depositMapKeys.push(_incomeWallet);
    }
    
    deposit.investorWallet = _wallet;
    deposit.bonusWallet = _bonusWallet;
    deposit.depositedETH.add(_wei);
    deposit.depositedTokens.add(_tokens);
    deposit.depositedBonusTokens.add(_bonusTokens);
    
    ONE.mint(address(this), _tokens.add(_bonusTokens)); //UNDONE
    
    emit DepositAdded(_wallet, _bonusWallet, _wei, _tokens, _bonusTokens);
  }

  /**
   * @dev Add deposit time lock for given wallet.
   *
   * @param _wallet address of wallet to got the tokens
   * @param _mainCliffAmount percent of token could taken before mainCliffTime
   * @param _mainCliffTime timestamp for main cliff
   * @param _additionalCliffAmount percent of token could taken before _additionalCliffTime
   * @param _additionalCliffTime timestamp for additional cliff
   *
   *
   *   |                                    /----------------
   *   |                                    |  all remaining
   *   |                                    |     tokens
   *   |                                    |
   *   |                                    |
   *   |                                    |
   *   |               /---------------------
   *   |               |  + additional cliff
   *   |               |        amount
   *   |   /-----------/
   *   |   |
   *   |   |  main cliff
   *   |   |    amount
   *   +===+===========+--------------------+-------------------> time
   *     Crowdsale    main cliff      additional cliff
   *      finish
   */
function assignDepositTimeLock(
    address _wallet,
    uint256 _mainCliffAmount,
    uint256 _mainCliffTime,
    uint256 _additionalCliffAmount,
    uint256 _additionalCliffTime
  )
    external onlyAdmins onlyWhileOpen
  {
    require(_wallet != address(0));
    require(_mainCliffTime > 0);
    require(_mainCliffAmount > 0 && _mainCliffAmount < 100);
    
    if (_additionalCliffTime > 0) {
      require(_additionalCliffTime > _mainCliffTime);
      require(_mainCliffAmount.add(_additionalCliffAmount) < 100);
    }
    
    DepositTimeLock storage timeLock = depositTimeLockMap[_wallet];
    timeLock.mainCliffAmount = _mainCliffAmount;
    timeLock.mainCliffTime = _mainCliffTime;
    timeLock.additionalCliffTime = _additionalCliffTime;
    timeLock.additionalCliffAmount = _additionalCliffAmount;
    
    emit DepositTimeLockAssigned(_wallet, _mainCliffAmount, _mainCliffTime, _additionalCliffAmount, _additionalCliffTime);
  }

  /**
   * @dev Remove deposit time lock
   *
   * @param _wallet address of wallet to got the tokens
   */
  function deleteDepositTimeLock(address _wallet) external onlyAdmins onlyWhileOpen {
    require(_wallet != address(0));
    
    delete depositTimeLockMap[_wallet];

    emit DepositTimeLockDeleted(_wallet);
  }
  
  /**
   * @dev Allow manager to refund deposits without kyc passed.
   *
   * @param _wallet the address of the investor wallet for ETC payments.
   */
  function refundDeposit(address _wallet) external onlyAdmins onlyKYCNotPassed {
    require(depositMap[_wallet].depositedTokens > 0);
    
    uint256 tokens = depositMap[_wallet].depositedTokens;
    uint256 bonusTokens = depositMap[_wallet].depositedBonusTokens;
    uint256 refundTokens = tokens.add(bonusTokens);
  
    require(refundTokens > 0);
    
    depositMap[_wallet].depositedTokens = 0;
    depositMap[_wallet].depositedBonusTokens = 0;
    
    ONE.burn(address(this), refundTokens);

    uint256 ETHToRefund = depositMap[_wallet].depositedETH;
    if (ETHToRefund > 0) {
      depositMap[_wallet].depositedETH = 0;
      _wallet.transfer(ETHToRefund);
    }
  
    emit RefundedDeposit(_wallet, ETHToRefund, refundTokens);
  }
  
  /**
   * @dev Investor should call this method to claim they tokens from deposit
   */
  function claimTokens() public onlyKYCPassed {
    address investor = msg.sender;
  
    DealDeposit storage deposit = depositMap[investor];
  
    require(deposit.depositedTokens > 0);
  
    uint256 depositedToken = deposit.depositedTokens;
    address investorWallet = deposit.investorWallet;
  
    DepositTimeLock storage timeLock = depositTimeLockMap[investor];
  
    uint256 vested;
    if (timeLock.mainCliffTime > 0 && timeLock.mainCliffTime <= now) {
      vested = depositedToken.mul(timeLock.mainCliffAmount).div(100);
    } else if (timeLock.additionalCliffTime > 0 && timeLock.additionalCliffTime <= now) {
      uint256 totalCliff = timeLock.mainCliffAmount.add(timeLock.additionalCliffAmount);
      vested = depositedToken.mul(totalCliff).div(100);
    } else {
      vested = depositedToken;
    }
  
    if (vested == 0) {
      return;
    }
  
    // Make sure the holder doesn't transfer more than what he already has.
    uint256 transferable = vested.sub(deposit.transferred);
    if (transferable == 0) {
      return;
    }
  
    deposit.transferred = deposit.transferred.add(transferable);
    ONE.transfer(investorWallet, transferable);
  
    emit TokenClaimed(investor, transferable);
  }

  /**
   * @return the rate in ONE per 1 ETH.
   */
  function getRate() public view returns (uint256) {
    if (now < (openingTime.add(33 days))) {return rate.mul(160).div(100);} //60%
    if (now < (openingTime.add(61 days))) {return rate.mul(150).div(100);} //50%
    if (now < (openingTime.add(115 days))) {return rate.mul(140).div(100);} //40%
    if (now < (openingTime.add(145 days))) {return rate.mul(130).div(100);} //30%
    if (now < (openingTime.add(208 days))) {return rate.mul(120).div(100);} //20%
    if (now < (openingTime.add(212 days))) {return rate.mul(110).div(100);} //10%
    if (now < (openingTime.add(216 days))) {return rate.mul(108).div(100);} //8%
    if (now < (openingTime.add(220 days))) {return rate.mul(106).div(100);} //6%
    if (now < (openingTime.add(224 days))) {return rate.mul(104).div(100);} //4%
    if (now < (openingTime.add(228 days))) {return rate.mul(102).div(100);} //2%
    
    return rate;
  }
  
  /**
   * @param _beneficiary the address of the investor wallet to get current bonus rate.
   */
  function getBonusRate(address _beneficiary) internal view returns (uint256) {
    uint256 bonusRateTime =  investorsMap[_beneficiary].bonusRateTime;
    uint256 bonusRate = investorsMap[_beneficiary].bonusRate;
    
    if (bonusRateTime >= now && bonusRate > 0) {
      return bonusRate;
    }
    
    return 0;
  }
  
  /**
   * @dev Must be called after crowdsale ends, to do some extra finalization
   * work. Calls the contract's finalization function.
   */
  function finishCrowdsale() onlyOwner public {
    require(!isFinalized);
    require(hasClosed() || hardCapReached());
  
    for (uint256 i = 0; i < invoiceMapKeys.length; i++) {
      address investorWallet = invoiceMapKeys[i];
      uint256 tokens = invoicesMap[investorWallet];
      
      addDeposit(investorWallet, investorWallet, address(0), 0, tokens, 0);
    }
  
    // Transfer all bonus tokens (not depends on KYC)
    for (uint256 i = 0; i < depositMapKeys.length; i++) {
      DealDeposit storage deposit = depositMap[depositMapKeys[i]];
 
      if (deposit.depositedBonusTokens > 0) {
        deposit.depositedBonusTokens = 0;
        ONE.transfer(deposit.bonusWallet, deposit.depositedBonusTokens);
    
        emit TokenClaimed(deposit.bonusWallet, deposit.depositedBonusTokens);
      }
    }
  
    uint256 newTotalSupply = ONE.totalSupply().mul(100).div(icoPart);
  
    ONE.mint(walletTeam, newTotalSupply.mul(teamPart).div(100));
    ONE.mint(walletAdvisers, newTotalSupply.mul(advisersPart).div(100));
    ONE.mint(walletFounders, newTotalSupply.mul(foundersPart).div(100));
    ONE.mint(walletReserve, newTotalSupply.mul(reservePart).div(100));
    
    ONE.finishMinting();
    
    emit CrowdsakeFinished();
    isFinalized = true;
  }
  
  /**
   * @dev Determines how ETH is stored/forwarded on purchases.
   */
  function forwardFunds() internal {
    wallet.transfer(msg.value);
  }
}
