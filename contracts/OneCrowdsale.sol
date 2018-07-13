pragma solidity ^0.4.19;

import "./crowdsale/FinalizableCrowdsale.sol";
import "./math/SafeMath.sol";
import "./OneSmartToken.sol";
/*
Чек лист:
- можно возвращать если не пройден кик
- дочинить депозиты
- везде добавить события
- вылизать интерфейс фиата
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
contract OneCrowdsale is FinalizableCrowdsale {
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
  
  /***********************************************************************/
  /**                              Structures
  /***********************************************************************/
  
  /**
  * The structure to hold private round condition for token distribution and
  * refund.
  * @see addUpdateDeal for details.
  */
  struct PreSaleConditions {
    address incomeWallet;
    address investorWallet;
    address finderWallet;
    uint256 weiMinAmount;
    uint256 bonusFinderShare;
    uint256 bonusRate;
    uint256 bonusRateTime;
    uint256 releaseTime;
    uint256 completed;
  }
  
  /**
  * The structure to hold private round condition for token distribution and
  * refund based on invoice payments.
  * @see addUpdateInvoiceDeal for details.
  */
  struct InvestorConditions {
    address investorWallet;
    uint256 tokenAmount;
    string invoiceId;
    uint256 releaseTime;
  }
  
  struct DealDeposit{
    address investorWallet;
    address bonusWallet;
    uint256 depositedETH;
    uint256 depositedTokens;
    uint256 depositedBonusTokens;
    uint256 releaseTime;
  }
 
  /***********************************************************************/
  /**                              Members
  /***********************************************************************/
  
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
  
  //Investors - used for ether presale and bonus token generation
  address[] public investorsMapKeys;
  mapping(address => PreSaleConditions) public investorsMap;
  
  //Invoice -used for non-ether presale token generation
  address[] public invoiceMapKeys;
  mapping(address => InvestorConditions) public invoicesMap;
  
  mapping(address => bool) public kykPassed;
  mapping(address => DealDeposit) public depositMap;

  /***********************************************************************/
  /**                              Modifiers
  /***********************************************************************/
  
  modifier onlyKYCPassed() {
    require(kykPassed[msg.sender]);
    _;
  }
  
  /**
   * @dev Reverts if beneficiary is not whitelisted. Can be used when extending this contract.
   */
  modifier onlyWhitelisted() {
    require(investorsMap[msg.sender].incomeWallet == msg.sender && investorsMap[msg.sender]);
    _;
  }
  
  /**
   * @dev Reverts if beneficiary is not whitelisted. Can be used when extending this contract.
   */
  modifier onlyNotCompleted() {
    require(investorsMap[msg.sender].completed == false);
    _;
  }
  
  /***********************************************************************/
  /**                              Events
  /***********************************************************************/
  
  event InvestorAdded(address indexed _grantee);
  event InvestorUpdated(address indexed _grantee);
  event InvestorDeleted(address indexed _grantee);
  event InvestorKycUpdated(address indexed _grantee, bool _oldValue, bool _newValue);
  
  event InvoiceAdded(address indexed _grantee);
  event InvoiceUpdated(address indexed _grantee);
  event InvoiceDeleted(address indexed _grantee);
  event InvoiceKycUpdated(address indexed _grantee, bool _oldValue, bool _newValue);
  
  /***********************************************************************/
  /**                              Constructor
  /***********************************************************************/
  
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
  
    depositMap[_beneficiary].investorWallet = investorDeal.investorWallet;
    depositMap[_beneficiary].bonusWallet = investorDeal.finderWallet;
    depositMap[_beneficiary].depositedETH = weiAmount;
    depositMap[_beneficiary].releaseTime = investorDeal.releaseTime;
    
    // get investor bonus rate based on current day from ICO start and personal deal rate
    uint256 bonusRate = getBonusRate(investorDeal.incomeWallet);
    uint256 bonusTokens = baseDealTokens.mul(bonusRate).div(100);
    
    // calculate bonus part in tokens
    if (bonusTokens > 0) {
      uint256 finderBonus = bonusTokens.mul(investorDeal.bonusFinderShare).div(100);
      uint256 investorBonus = bonusTokens.sub(finderBonus);
  
      if (investorBonus > 0) {
        baseDealTokens.add(investorBonus);
      }
      
      if (finderBonus > 0) {
        depositMap[_beneficiary].depositedBonusTokens.add(finderBonus);
      }
    }
    depositMap[_beneficiary].depositedTokens = baseDealTokens;
    investorsMap[_beneficiary].completed = true;
  
    // update state
    weiRaised = weiRaised.add(weiAmount);
    
    uint256 totalTokens = baseDealTokens.add(bonusTokens);
    
    ONE.mint(wallet, totalTokens); //UNDONE
    forwardFunds();
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
  
  /**
  * @dev Update KYC flag for deal.
  *
  * @param _wallet address The address of the investor wallet for ETC payments.
  * @param _value flag determining is investor passed KYC procedure for bank complience.
  */
  function updateInvestorKYC(address _wallet, bool _value) external onlyOwner {
    require(_wallet != address(0));
    require(kykPassed[_wallet] != _value);
    
    emit InvestorKycUpdated(_wallet, kykPassed[_wallet], _value);
    kykPassed[_wallet] = _value;
  }
  
  /**
  * @dev Adds/Updates address and token deal allocation for token investors.
  * All tokens during pre-sale are allocated to pre-sale, buyers.
  *
  * NOTE: According to EU/US laws we can`t handle and use any fees from investors
  * without passed KYC (Know Your Customer) procedure to ensure verification processes
  * in order to reduce fraud, money laundering and scams. In order to do this, it is
  * important to authenticate money trail from start to end. That’s when KYC comes
  * into practice.
  *
  * @param _incomeWallet address The address of the investor wallet for ETC payments.
  * @param _investorWallet address The address of the investor wallet for ONE tokens.
  * @param _bonusWallet address The address of the finder for ONE tokens.
  * @param _weiMinAmount minimum amount of ETH for payment.
  * @param _bonusRate ONE to ETH rate for investor
  * @param _bonusRateTime timestamp when token rate should be used
  * @param _bonusFinderShare amount of bonus ONE tokens distributed between _investorWallet and _bonusWallet
  * @param _kycPassed flag determining is investor passed KYC procedure for bank complience.
  * @param _releaseTime timestamp when token release is enabled
  */
  function addUpdateDeal(
    address _incomeWallet,
    address _investorWallet,
    address _bonusWallet,
    uint256 _weiMinAmount,
    uint256 _bonusRate,
    uint256 _bonusRateTime,
    uint256 _bonusFinderShare,
    bool _kycPassed,
    uint256 _releaseTime
  )
    external
    onlyOwner
    onlyWhileOpen
  {
    require(_incomeWallet != address(0));
    require(_investorWallet != address(0));
    require(_releaseTime > 0);
    require(_weiMinAmount > 0);
    
    if (_bonusRate > 0) {
      require(_bonusRateTime > now);
    }
    
    if (_bonusFinderShare > 0) {
      require(_bonusFinderShare <= 100);
      require(_bonusWallet != address(0));
    }
    
    // Adding new key if not present:
    if (investorsMap[_incomeWallet].incomeWallet == address(0)) {
      investorsMapKeys.push(_incomeWallet);
      emit InvestorAdded(_incomeWallet);
    } else {
      emit InvestorUpdated(_incomeWallet);
    }
  
    investorsMap[_incomeWallet].incomeWallet = _incomeWallet;
    investorsMap[_incomeWallet].investorWallet = _investorWallet;
    investorsMap[_incomeWallet].finderWallet = _bonusWallet;
    investorsMap[_incomeWallet].weiMinAmount = _weiMinAmount;
    investorsMap[_incomeWallet].bonusRate = _bonusRate;
    investorsMap[_incomeWallet].bonusRateTime = _bonusRateTime;
    investorsMap[_incomeWallet].bonusFinderShare = _bonusFinderShare;
    investorsMap[_incomeWallet].releaseTime = _releaseTime;
    investorsMap[_incomeWallet].completed = false;
    
    this.updateInvestorKYC(_incomeWallet, _kycPassed);
  }
  
  /**
  * @dev Deletes entries from the deal list.
  *
  * @param _investorETCIncomeWallet address The address of the investor wallet for ETC payments.
  */
  function deleteDeal(address _investorETCIncomeWallet) external onlyOwner onlyWhileOpen {
    require(_investorETCIncomeWallet != address(0));
    require(investorsMap[_investorETCIncomeWallet].incomeWallet != address(0));
  
    //delete from the map:
    delete investorsMap[_investorETCIncomeWallet];
  
    //delete from the array (keys):
    uint256 index;
    for (uint256 i = 0; i < investorsMapKeys.length; i++) {
      if (investorsMapKeys[i] == _investorETCIncomeWallet) {
        index = i;
        break;
      }
    }
  
    investorsMapKeys[index] = investorsMapKeys[investorsMapKeys.length - 1];
    delete investorsMapKeys[investorsMapKeys.length - 1];
    investorsMapKeys.length--;
  
    emit InvestorDeleted(_investorETCIncomeWallet);
  }
 
  
  /**
  * @dev Adds/Updates address and token allocation for token investors with
  * BTC/fiat based payments.
  *
  * NOTE: According to EU/US laws we can`t handle and use any fees from investors
  * without passed KYC (Know Your Customer) procedure to ensure verification processes
  * in order to reduce fraud, money laundering and scams. In order to do this, it is
  * important to authenticate money trail from start to end. That’s when KYC comes
  * into practice.
  *
  * @param _investorWallet address The address of the investor wallet for ONE tokens.
  * @param _tokenAmount ONE token amount based on invoice income.
  * @param _invoiceId fiat payment invoice id or BTC transaction id.
  * @param _kycPassed flag determining is investor passed KYC procedure for bank complience.
  * @param _releaseTime timestamp when token release is enabled
  */
  function addUpdateInvoiceDeal(
    address _investorWallet,
    uint256 _tokenAmount,
    string _invoiceId,
    bool _kycPassed,
    uint256 _releaseTime
  )
    external
    onlyOwner
    onlyWhileOpen
  {
    require(_investorWallet != address(0));
    require(bytes(_invoiceId).length > MIN_INVOICE_LENGTH);
    require(_tokenAmount > 0);
    require(_releaseTime > 0);
  
    // Adding new key if not present:
    if (invoicesMap[_investorWallet].investorWallet == address(0)) {
      invoiceMapKeys.push(_investorWallet);
      emit InvoiceAdded(_investorWallet);
    }
    else {
      emit InvoiceUpdated(_investorWallet);
    }
  
    invoicesMap[_investorWallet].investorWallet = _investorWallet;
    invoicesMap[_investorWallet].tokenAmount = _tokenAmount;
    invoicesMap[_investorWallet].invoiceId = _invoiceId;
    invoicesMap[_investorWallet].releaseTime = _releaseTime;
    
    this.updateInvestorKYC(_investorWallet, _kycPassed);
  }
  
  /**
  * @dev Deletes entries from the invoice list.
  *
  * @param _investorOneTokenWallet address The address of the investor wallet for ONE tokens.
  */
  function deleteInvoiceDeal(address _investorOneTokenWallet) external onlyOwner onlyWhileOpen {
    require(_investorOneTokenWallet != address(0));
    require(invoicesMap[_investorOneTokenWallet].investorWallet != address(0));
  
    //delete from the map:
    delete invoicesMap[_investorOneTokenWallet];
  
    //delete from the array (keys):
    uint256 index;
    for (uint256 i = 0; i < invoiceMapKeys.length; i++) {
      if (investorsMapKeys[i] == _investorOneTokenWallet) {
        index = i;
        break;
      }
    }
  
    invoiceMapKeys[index] = invoiceMapKeys[invoiceMapKeys.length - 1];
    delete invoiceMapKeys[invoiceMapKeys.length - 1];
    invoiceMapKeys.length--;
  
    emit InvoiceDeleted(_investorOneTokenWallet);
  }

  //endregion
  
  
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
  * UNDONE docblock
  */


  //@Override Impl FinalizableCrowdsale
  function finalization() internal onlyOwner {
    super.finalization();
    
    //TODO  bonuses for the pre crowdsale invoice based payments:
    for (uint256 i = 0; i < invoiceMapKeys.length; i++) {
    
    }
    
    uint256 newTotalSupply = ONE.totalSupply().mul(100).div(icoPart);
    
    ONE.mint(walletTeam, newTotalSupply.mul(teamPart).div(100));
    ONE.mint(walletAdvisers, newTotalSupply.mul(advisersPart).div(100));
    ONE.mint(walletFounders, newTotalSupply.mul(foundersPart).div(100));
    ONE.mint(walletReserve, newTotalSupply.mul(reservePart).div(100));
  }
}
