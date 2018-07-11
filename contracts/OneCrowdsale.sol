pragma solidity ^0.4.19;

import "./crowdsale/FinalizableCrowdsale.sol";
import "./crowdsale/CappedCrowdsale.sol";
import "./crowdsale/LockRefundVault.sol";

import "./OneSmartToken.sol";

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
contract OneCrowdsale is CappedCrowdsale, FinalizableCrowdsale {

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
  struct DealConditions {
    address _investorETCIncomeWallet;
    address _investorOneTokenWallet;
    address _investorBonusOneTokenWallet;
    address _finderOneTokenWallet;
    uint256 _finderBonusWalletShare;
    uint256 _weiMinAmount;
    uint256 _oneRate;
    uint256 _oneRateTime;
    bool _kycPassed;
    uint256 _releaseTime;
  }
  
  /**
  * The structure to hold private round condition for token distribution and
  * refund based on invoice payments.
  * @see addUpdateInvoiceDeal for details.
  */
  struct InvoiceDealConditions {
    address _investorOneTokenWallet;
    uint256 _tokenAmount;
    string _invoiceId;
    bool _kycPassed;
    uint256 _releaseTime;
  }
  
  /***********************************************************************/
  /**                              Modifiers
  /***********************************************************************/
  
  modifier onlyWhileSale() {
    require(isActive());
    _;
  }
  
  modifier onlyAfterSale() {
    //UNDONE
    require(!isActive());
    _;
  }
  
  /**
   * @dev Reverts if beneficiary is not whitelisted. Can be used when extending this contract.
   */
  modifier isWhitelisted(address _beneficiary) {
    require(investorsMap[_beneficiary]._investorETCIncomeWallet != address(0));
    _;
  }
  
  /***********************************************************************/
  /**                              Members
  /***********************************************************************/

  // wallets address for 41% of ONE allocation
  address public walletTeam; // 12% of the total number of ONE tokens will be allocated to the team and SDK developers
  address public walletAdvisers; // 3% of the total number of ONE tokens will be allocated to professional fees and Bounties
  address public walletFounders; // 15% of the total number of ONE tokens will be allocated to Protocol One founders
  address public walletReserve; // 10% of the total number of ONE tokens will be allocated to Protocol One and as a reserve for the company to be used for future strategic plans for the created ecosystem
  address public walletMarketing; // 10% of the total number of ERC for supporting ICO process.
  
  //Investors - used for ether presale and bonus token generation
  address[] public investorsMapKeys;
  mapping(address => DealConditions) public investorsMap;
  
  //Invoice -used for non-ether presale token generation
  address[] public invoiceMapKeys;
  mapping(address => InvoiceDealConditions) public invoicesMap;
  
  // The refund vault
  LockRefundVault public refundVault;
  
  /***********************************************************************/
  /**                              Events
  /***********************************************************************/
  
  event InvestorAdded(address indexed _grantee);
  event InvestorUpdated(address indexed _grantee);
  event InvestorDeleted(address indexed _grantee);
  event InvestorKycUpdated(address indexed _grantee, bool _oldValue, bool _newValue);
  event TokenPurchaseByInvestor(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  
  event InvoiceAdded(address indexed _grantee);
  event InvoiceUpdated(address indexed _grantee);
  event InvoiceDeleted(address indexed _grantee);
  event InvoiceKycUpdated(address indexed _grantee, bool _oldValue, bool _newValue);
  
  /***********************************************************************/
  /**                              Constructor
  /***********************************************************************/
  
  constructor(
    uint256 _openingTime,
    uint256 _closingTime,
    address _wallet,
    address _walletTeam,
    address _walletAdvisers,
    address _walletFounders,
    address _walletReserve,
    address _walletMarketing,
    uint256 _cap,
    uint256 _goal,
    OneSmartToken _oneToken,
    LockRefundVault _refundVault
  )
    public
    Crowdsale(_openingTime, _closingTime, EXCHANGE_RATE, _wallet, _oneToken)
    CappedCrowdsale(_cap)
  {
    require(_walletTeam != address(0));
    require(_walletAdvisers != address(0));
    require(_walletFounders != address(0));
    require(_walletReserve != address(0));
    require(_walletMarketing != address(0));
    
    require(_oneToken != address(0));
    require(_refundVault != address(0));

    require(_goal <= _cap);
  
    walletTeam = _walletTeam;
    walletAdvisers = _walletAdvisers;
    walletFounders = _walletFounders;
    walletReserve = _walletReserve;
    walletMarketing = _walletMarketing;
    
    token = _oneToken;
    refundVault = _refundVault;
  }
  
  
  /***********************************************************************/
  /**                   Crowdsale external interface
  /***********************************************************************/
  
  /**
   * @dev fallback function ***DO NOT OVERRIDE***
   */
  function () external payable {
    buyTokens(msg.sender);
  }
  
  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   * @param _beneficiary Address performing the token purchase
   */
  function buyTokens(address _beneficiary) public payable isWhitelisted onlyWhileSale {
    DealConditions investorDeal = investorsMap[_beneficiary];
    require(investorDeal._investorETCIncomeWallet == _beneficiary);
    require(investorDeal._weiMinAmount <= _weiAmount);
    
    uint256 weiAmount = msg.value;
    _preValidatePurchase(_beneficiary, weiAmount);
    
    // get investor rate based on current day from ICO start and personal deal rate
    uint256 investorRate = getInvestorRate(investorDeal._investorETCIncomeWallet);
    
    // calculate token amount to be created based on fixed rate
    uint256 baseDealTokens = weiAmount.mul(rate);
    
    // calculate token amount to be created based on personal investor rate
    uint256 investorDealTokens = weiAmount.mul(investorRate);
    
    // calculate bonus part in tokens
    uint256 bonusTokens = investorDealTokens.sub(baseDealTokens);
    if (bonusTokens > 0) {
      uint256 finderBonus = bonusTokens.mul(investorDeal._finderBonusWalletShare).div(100);
      uint256 investorBonus = bonusTokens.sub(finderBonus);
      
      if (finderBonus > 0) {
        //TODO move all bonus tokens to investorDeal._finderOneTokenWallet
      }
      
      if (investorBonus > 0) {
        //TODO move all bonus tokens to investorDeal._investorBonusOneTokenWallet
      }
    }
    
    // update state
    weiRaised = weiRaised.add(weiAmount);
    
    _deliverTokens(address(refundVault), tokens);
    refundVault.deposit.value(msg.value)(msg.sender, tokens);
    
    
    emit TokenPurchase(
      msg.sender,
      address(refundVault),
      weiAmount,
      tokens
    );
    
    _forwardFunds();
    _postValidatePurchase(_beneficiary, weiAmount);
  }
  
  
  /***********************************************************************/
  /**                              Public Methods
  /***********************************************************************/
  
  /**
  * @return true if the crowdsale is active, hence users can buy tokens
  */
  function isActive() public view returns (bool) {
    return block.timestamp >= openingTime && block.timestamp <= closingTime;
  }
  
  /**
  * @return the rate in ONE per 1 ETH.
  */
  function getRate() public view returns (uint256) {
    //UNDONE final rate table
    if (now < (startTime.add(1 days))) {return 1000;}
    if (now < (startTime.add(30 days))) {return 550;}
    
    return rate;
  }
  
  function rejectInvestorDeal(address _beneficiary) public onlyOwner onlyAfterSale {
    // TODO
  }
  
  function rejectInvoiceDeal(address _beneficiary) public onlyOwner onlyAfterSale {
    // TODO
  }
  
  /***********************************************************************/
  /**                              External Methods
  /***********************************************************************/
  
  //region Manage deal structures
  
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
  * @param _investorETCIncomeWallet address The address of the investor wallet for ETC payments.
  * @param _investorOneTokenWallet address The address of the investor wallet for ONE tokens.
  * @param _investorBonusOneTokenWallet address The address of the investor wallet for bonus ONE tokens.
  * @param _finderOneTokenWallet address The address of the finder for ONE tokens.
  * @param _weiMinAmount minimum amount of ETH for payment.
  * @param _oneRate ONE to ETH rate for investor
  * @param _oneRateTime timestamp when token rate should be used
  * @param _investorBonusAndFinderWalletShare amount of bonus ONE tokens distributed between _investorBonusOneTokenWallet and _finderOneTokenWallet
  * @param _kycPassed flag determining is investor passed KYC procedure for bank complience.
  * @param _releaseTime timestamp when token release is enabled
  */
  function addUpdateDeal(
    address _investorETCIncomeWallet,
    address _investorOneTokenWallet,
    address _investorBonusOneTokenWallet,
    address _finderOneTokenWallet,
    uint256 _weiMinAmount,
    uint256 _oneRate,
    uint256 _oneRateTime,
    uint256 _finderBonusWalletShare,
    bool _kycPassed,
    uint256 _releaseTime
  )
    external
    onlyOwner
    onlyWhileSale
  {
    require(_investorETCIncomeWallet != address(0));
    require(_investorOneTokenWallet != address(0));
    require(_investorBonusOneTokenWallet != address(0));
    require(_releaseTime > 0);
    require(_weiMinAmount > 0);
    
    if (_oneRate > 0) {
      require(_oneRateTime > now);
    }
    
    if (_finderBonusWalletShare > 0) {
      require(_finderBonusWalletShare <= 100);
      require(_finderOneTokenWallet != address(0));
    }
   
    // Adding new key if not present:
    if (investorsMap[_investorETCIncomeWallet]._investorETCIncomeWallet == address(0)) {
      investorsMapKeys.push(_investorETCIncomeWallet);
      InvestorAdded(_investorETCIncomeWallet);
    } else {
      InvestorUpdated(_investorETCIncomeWallet);
    }
  
    investorsMap[_investorETCIncomeWallet]._investorETCIncomeWallet = _investorETCIncomeWallet;
    investorsMap[_investorETCIncomeWallet]._investorOneTokenWallet = _investorOneTokenWallet;
    investorsMap[_investorETCIncomeWallet]._investorBonusOneTokenWallet = _investorBonusOneTokenWallet;
    investorsMap[_investorETCIncomeWallet]._finderOneTokenWallet = _finderOneTokenWallet;
    investorsMap[_investorETCIncomeWallet]._finderETCWallet = _finderETCWallet;
    investorsMap[_investorETCIncomeWallet]._finderBonusWalletShare = _finderBonusWalletShare;
    investorsMap[_investorETCIncomeWallet]._weiMinAmount = _weiMinAmount;
    investorsMap[_investorETCIncomeWallet]._oneRate = _oneRate;
    investorsMap[_investorETCIncomeWallet]._oneRateTime = _oneRateTime;
    investorsMap[_investorETCIncomeWallet]._kycPassed = _kycPassed;
    investorsMap[_investorETCIncomeWallet]._releaseTime = _releaseTime;
  }
  
  /**
  * @dev Deletes entries from the deal list.
  *
  * @param _investorETCIncomeWallet address The address of the investor wallet for ETC payments.
  */
  function deleteDeal(address _investorETCIncomeWallet) external onlyOwner onlyWhileSale {
    require(_investorETCIncomeWallet != address(0));
    require(investorsMap[_investorETCIncomeWallet]._investorETCIncomeWallet != address(0));
  
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
  
    InvestorDeleted(_investorETCIncomeWallet);
  }
  
  /**
  * @dev Update KYC flag for deal.
  *
  * @param _wallet address The address of the investor wallet for ETC payments.
  * @param _value flag determining is investor passed KYC procedure for bank complience.
  */
  function updateInvestorKYC(address _wallet, bool _value) external onlyOwner {
    require(_wallet != address(0));
    require(investorsMap[_wallet]._investorETCIncomeWallet == _wallet);
    require(investorsMap[_wallet]._kycPassed != _value);
  
    InvestorKycUpdated(_wallet, investorsMap[_wallet]._kycPassed, _value);
    investorsMap[_wallet]._kycPassed = _value;
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
  * @param _investorOneTokenWallet address The address of the investor wallet for ONE tokens.
  * @param _tokenAmount ONE token amount based on invoice income.
  * @param _invoiceId fiat payment invoice id or BTC transaction id.
  * @param _kycPassed flag determining is investor passed KYC procedure for bank complience.
  * @param _releaseTime timestamp when token release is enabled
  */
  function addUpdateInvoiceDeal(
    address _investorOneTokenWallet,
    uint256 _tokenAmount,
    string _invoiceId,
    bool _kycPassed,
    uint256 _releaseTime
  )
    external
    onlyOwner
    onlyWhileSale
  {
    require(_investorOneTokenWallet != address(0));
    require(bytes(_invoiceId).length > MIN_INVOICE_LENGTH);
    require(_tokenAmount > 0);
    require(_releaseTime > 0);
  
    // Adding new key if not present:
    if (invoicesMap[_investorOneTokenWallet]._investorOneTokenWallet == address(0)) {
      invoiceMapKeys.push(_investorOneTokenWallet);
      InvoiceAdded(_investorOneTokenWallet);
    }
    else {
      InvoiceUpdated(_investorOneTokenWallet);
    }
  
    invoicesMap[_investorETCIncomeWallet]._investorOneTokenWallet = _investorOneTokenWallet;
    invoicesMap[_investorETCIncomeWallet]._tokenAmount = _tokenAmount;
    invoicesMap[_investorETCIncomeWallet]._invoiceId = _invoiceId;
    invoicesMap[_investorETCIncomeWallet]._kycPassed = _kycPassed;
    invoicesMap[_investorETCIncomeWallet]._releaseTime = _releaseTime;
  }
  
  /**
  * @dev Deletes entries from the invoice list.
  *
  * @param _investorOneTokenWallet address The address of the investor wallet for ONE tokens.
  */
  function deleteInvoiceDeal(address _investorOneTokenWallet) external onlyOwner onlyWhileSale {
    require(_investorOneTokenWallet != address(0));
    require(invoicesMap[_investorOneTokenWallet]._investorOneTokenWallet != address(0));
  
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
  
    InvoiceDeleted(_investorOneTokenWallet);
  }
  
  /**
  * @dev Update KYC flag for invoice based deal.
  *
  * @param _wallet address The address of the investor wallet for ONE tokens.
  * @param _value flag determining is investor passed KYC procedure for bank complience.
  */
  function updateInvoiceKYC(address _wallet, bool _value) external onlyOwner {
    require(_wallet != address(0));
    require(invoicesMap[_wallet]._investorOneTokenWallet == _wallet);
    require(invoicesMap[_wallet]._kycPassed != _value);
  
    InvoiceKycUpdated(_wallet, invoicesMap[_wallet]._kycPassed, _value);
    invoicesMap[_wallet]._kycPassed = _value;
  }
  
  //endregion
  
  
  /***********************************************************************/
  /**                         Internals
  /***********************************************************************/
  
  /**
  * UNDONE docblock
  */
  function getInvestorRate(address _beneficiary) internal isWhitelisted view returns (uint256) {
    uint256 oneRateTime =  investorsMap[_beneficiary]._oneRateTime;
    uint256 oneRate = investorsMap[_beneficiary]._oneRate;
    
    if (oneRateTime >= now && oneRate > 0) {
      return oneRate;
    }
    
    return getRate();
  }

  /**
  * @dev Overrides delivery by minting tokens upon purchase.
  *
  * @param _beneficiary Token purchaser
  * @param _tokenAmount Number of tokens to be minted
  */
  function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
    require(MintableToken(token).mint(_beneficiary, _tokenAmount));
  }

  //@Override Impl FinalizableCrowdsale
  function finalization() internal onlyOwner {
    super.finalization();
    
    //TODO  bonuses for the pre crowdsale invoice based payments:
    for (uint256 i = 0; i < invoiceMapKeys.length; i++) {
    
    }
    
    // Adding 41% of the total token supply (59% were generated during the crowdsale)
    // using a simple rule of proportion
    uint256 newTotalSupply = token.totalSupply().mul(41).div(59);
    
    // 12% of the total number of ONE tokens will be allocated to the team and SDK developers
    _deliverTokens(walletTeam, newTotalSupply.mul(12).div(100));
    
    // 3% of the total number of ONE tokens will be allocated to professional fees and Bounties
    _deliverTokens(walletAdvisers, newTotalSupply.mul(3).div(100));
    
    // 15% of the total number of ONE tokens will be allocated to Protocol One founders
    _deliverTokens(walletFounders, newTotalSupply.mul(15).div(100));
    
    // 10% of the total number of ONE tokens will be allocated to Protocol One,
    // and as a reserve for the company to be used for future strategic plans for the created ecosystem
    _deliverTokens(walletReserve, newTotalSupply.mul(10).div(100));
  }
}
