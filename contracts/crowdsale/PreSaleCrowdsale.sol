pragma solidity ^0.4.24;

import "../math/SafeMath.sol";
import "./Crowdsale.sol";


/**
 * @title FinalizableCrowdsale
 * @dev Extension of Crowdsale where an owner can do extra work
 * after finishing.
 */
contract PreSaleCrowdsale is Crowdsale {
  using SafeMath for uint256;
  
  /**
  * The structure to hold private round condition for token distribution and
  * refund.
  * @see addUpdateDeal for details.
  */
  struct PreSaleConditions  {
    address wallet;
    address bonusWallet;
    uint256 weiMinAmount;
    uint256 bonusShare;
    uint256 bonusRate;
    uint256 bonusRateTime;
    bool completed;
  }
  
  event InvestorAdded(address indexed _wallet);
  event InvestorUpdated(address indexed _wallet);
  event InvestorDeleted(address indexed _wallet);
  
  event InvoiceAdded(address indexed _wallet, uint256 _tokenAmount, string _invoiceId);
  event InvoiceUpdated(address indexed _wallet, uint256 _tokenAmount, string _invoiceId);
  event InvoiceDeleted(address indexed _wallet);
  
  event KYCUpdated(address indexed _grantee, bool _oldValue, bool _value);
 
  modifier onlyKYCPassed() {
    require(kykPassed[msg.sender]);
    _;
  }
  
  modifier onlyKYCNotPassed() {
    require(kykPassed[msg.sender] == false);
    _;
  }
  
  /**
   * @dev Reverts if beneficiary is not whitelisted. Can be used when extending this contract.
   */
  modifier onlyWhitelisted() {
    require(investorsMap[msg.sender].wallet != address(0));
    _;
  }
  
  //Investors - used for ether presale and bonus token generation
  address[] public investorsMapKeys;
  mapping(address => PreSaleConditions) public investorsMap;
  
  //Invoice -used for non-ether presale token generation
  address[] public invoiceMapKeys;
  mapping(address => uint256) public invoicesMap;
  
  mapping(address => bool) public kykPassed;
  
  
  /**
   * @dev Update KYC flag for deal.
   *
   * NOTE: According to EU/US laws we can`t handle and use any fees from investors
   * without passed KYC (Know Your Customer) procedure to ensure verification processes
   * in order to reduce fraud, money laundering and scams. In order to do this, it is
   * important to authenticate money trail from start to end. That’s when KYC comes
   * into practice.
   *
   * @param _wallet address The address of the investor wallet for ETC payments.
   * @param _value flag determining is investor passed KYC procedure for bank complience.
   */
  function updateInvestorKYC(address _wallet, bool _value) external onlyAdmins {
    require(_wallet != address(0));
    require(kykPassed[_wallet] != _value);
    
    bool _oldValue = kykPassed[_wallet];
    kykPassed[_wallet] = _value;
  
    emit KYCUpdated(_wallet, _oldValue, _value);
  }
  
  /**
   * @dev Adds/Updates address and token deal allocation for token investors.
   * All tokens during pre-sale are allocated to pre-sale, buyers.
   *
   * @param _incomeWallet address The address of the investor wallet for ETC payments.
   * @param _wallet address The address of the investor wallet for ONE tokens.
   * @param _bonusWallet address The address of the finder for ONE tokens.
   * @param _weiMinAmount minimum amount of ETH for payment.
   * @param _bonusRate ONE to ETH rate for investor
   * @param _bonusRateTime timestamp when token rate should be used
   * @param _bonusShare amount of bonus ONE tokens distributed between _investorWallet and _bonusWallet
   */
  function addUpdatePreSaleDeal(
    address _incomeWallet,
    address _wallet,
    address _bonusWallet,
    uint256 _weiMinAmount,
    uint256 _bonusRate,
    uint256 _bonusRateTime,
    uint256 _bonusShare
  )
    external onlyAdmins onlyWhileOpen
  {
    require(_incomeWallet != address(0));
    require(_wallet != address(0));
    require(_weiMinAmount > 0);

    if (_bonusRate > 0) {
      require(_bonusRateTime > now);
    }

    if (_bonusShare > 0) {
      require(_bonusShare <= 100);
      require(_bonusWallet != address(0));
    }

    PreSaleConditions storage investor = investorsMap[_incomeWallet];
    // Adding new key if not present:
    if (investor.wallet == address(0)) {
      investorsMapKeys.push(_wallet);
      emit InvestorAdded(_incomeWallet);
    } else {
      emit InvestorUpdated(_incomeWallet);
    }
   
    investor.wallet = _wallet;
    investor.weiMinAmount = _weiMinAmount;
    investor.bonusWallet = _bonusWallet;
    investor.bonusRate = _bonusRate;
    investor.bonusRateTime = _bonusRateTime;
    investor.bonusShare = _bonusShare;
    investor.completed = false;
  }
  
  /**
   * @dev Deletes entries from the deal list.
   *
   * @param _incomeWallet address The address of the investor wallet for ETC payments.
   */
  function deletePreSaleDeal(address _incomeWallet) external onlyAdmins onlyWhileOpen {
    require(investorsMap[_incomeWallet].wallet != address(0));
    
    //delete from the map:
    delete investorsMap[_incomeWallet];
    
    //delete from the array (keys):
    uint256 index;
    for (uint256 i = 0; i < investorsMapKeys.length; i++) {
      if (investorsMapKeys[i] == _incomeWallet) {
        index = i;
        break;
      }
    }
    
    investorsMapKeys[index] = investorsMapKeys[investorsMapKeys.length - 1];
    delete investorsMapKeys[investorsMapKeys.length - 1];
    investorsMapKeys.length--;
    
    emit InvestorDeleted(_incomeWallet);
  }
  
  
  /**
   * @dev Adds/Updates address and token allocation for token investors with
   * BTC/fiat based payments.
   *
   * @param _wallet address The address of the investor wallet for ONE tokens.
   * @param _tokens ONE token amount based on invoice income.
   * @param _invoiceId fiat payment invoice id or BTC transaction id.
   */
  function addUpdateInvoice(
    address _wallet,
    uint256 _tokens,
    string _invoiceId
  )
    external onlyAdmins onlyWhileOpen
  {
    require(_wallet != address(0));
    require(_tokens > 0);
  
    uint256 amount = invoicesMap[_wallet];
    
    // Adding new key if not present:
    if (amount == 0) {
      invoiceMapKeys.push(_wallet);
      emit InvoiceAdded(_wallet, _tokens, _invoiceId);
    }
    else {
      emit InvoiceUpdated(_wallet, _tokens, _invoiceId);
    }
    
    invoicesMap[_wallet] = _tokens;
  }
  
  /**
   * @dev Deletes entries from the invoice list.
   *
   * @param _wallet address The address of the investor wallet for ONE tokens.
   */
  function deleteInvoice(address _wallet) external onlyAdmins onlyWhileOpen {
    require(_wallet != address(0));
    require(invoicesMap[_wallet] > 0);

    //delete from the map:
    delete invoicesMap[_wallet];

    //delete from the array (keys):
    uint256 index;
    for (uint256 i = 0; i < invoiceMapKeys.length; i++) {
      if (invoiceMapKeys[i] == _wallet) {
        index = i;
        break;
      }
    }    
    
    invoiceMapKeys[index] = invoiceMapKeys[invoiceMapKeys.length - 1];
    delete invoiceMapKeys[invoiceMapKeys.length - 1];
    invoiceMapKeys.length--;

    emit InvoiceDeleted(_wallet);
  }
}