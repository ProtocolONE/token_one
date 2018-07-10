pragma solidity ^0.4.19;

import "openzeppelin-solidity/contracts/crowdsale/emission/MintedCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/distribution/FinalizableCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "./OneSmartToken.sol";


contract OneCrowdsale is MintedCrowdsale, TimedCrowdsale, CappedCrowdsale, FinalizableCrowdsale {
  
  struct User {
    address _bonusPart;
    address _bonusCommission;
    uint256 _bonusPercent;
    uint256 _tokensToTransfer;
    uint256 _poneTokensToTransfer;
    string _invoiceId;
    bool _kycFlag;
  }
  
  // wallets address for 41% of ONE allocation
  address public walletTeam;
  address public walletAdvisers;
  address public walletFounders;
  address public walletReserve;
  
  mapping(address => User) public presaleBeneficiary;
  mapping(address => bool) public whitelist;
  
  /**
   * @dev Reverts if beneficiary is not whitelisted. Can be used when extending this contract.
   */
  modifier isWhitelisted(address _beneficiary) {
    require(whitelist[_beneficiary]);
    _;
  }
  
  function OneCrowdsale(
    uint256 _openingTime,
    uint256 _closingTime,
    uint256 _rate,
    address _wallet,
    address _walletTeam,
    address _walletAdvisers,
    address _walletFounders,
    address _walletReserve,
    uint256 _cap,
    OneSmartToken _token
  )
    public
    Crowdsale(_rate, _wallet, _token)
    CappedCrowdsale(_cap)
    TimedCrowdsale(_openingTime, _closingTime)
  {
    require(_walletTeam != address(0));
    require(_walletAdvisers != address(0));
    require(_walletFounders != address(0));
    require(_walletReserve != address(0));
  
    walletTeam = _walletTeam;
    walletAdvisers = _walletAdvisers;
    walletFounders = _walletFounders;
    walletReserve = _walletReserve;
    
    token = _token;
  }
  
  /**
   * @dev Adds single address to whitelist.
   * @param _beneficiary Address to be added to the whitelist
   */
  function addToWhitelist(address _beneficiary) private onlyOwner {
    whitelist[_beneficiary] = true;
  }
  
  /**
   * @dev Removes single address from whitelist.
   * @param _beneficiary Address to be removed to the whitelist
   */
  function removeFromWhitelist(address _beneficiary) private onlyOwner {
    whitelist[_beneficiary] = false;
  }
  
  function requestOnCryptoTransfer(
    address _beneficiary,
    address _bonusPartBeneficiary,
    address _bonusCommission,
    uint256 _bonusPercent,
    uint256 _tokensToTransfer,
    uint256 _poneTokensToTransfer,
    bool _kycFlag
  )
    public
    onlyOwner
  {
    require(_beneficiary != address(0));
    require(_tokensToTransfer > 0);
    
    // TODO validation
    addToWhitelist(_beneficiary);
    presaleBeneficiary[_beneficiary] = User(
      _bonusPartBeneficiary,
      _bonusCommission,
      _bonusPercent,
      _tokensToTransfer,
      _poneTokensToTransfer,
      "",
      _kycFlag
    );
  }

  function requestOnInvoiceTransfer(
    address _beneficiary,
    address _bonusPart,
    uint256 _bonusPercent,
    uint256 _tokensToTransfer,
    uint256 _poneTokensToTransfer,
    string _invoiceId,
    bool _kycFlag
  )
    public onlyOwner
  {
    // TODO validation
    addToWhitelist(_beneficiary);
    presaleBeneficiary[_beneficiary] = User(
      _bonusPart,
      0,
      _bonusPercent,
      _tokensToTransfer,
      _poneTokensToTransfer,
      _invoiceId,
      _kycFlag
    );
  }
  
  function makeBonusPaymanet() internal {
    // process customer map
  }
  
  function deleteRestBonus() internal {
    // TODO
  }
  
  function rejectPayment(address _beneficiary) internal onlyOwner {
    // TODO
  }
  
  // Add return list
  function getListOfNonKyc() internal onlyOwner {
    // TODO
    // Form list from map
  }
  
  function updateKYC(address _beneficiary) internal onlyOwner {
    
  }
  
  //@Override
  function finalization() internal onlyOwner {
    super.finalization();
    
    //TODO  bonuses for the pre crowdsale grantees:
    
    // Adding 41% of the total token supply (59% were generated during the crowdsale)
    // using a simple rule of proportion
    uint256 newTotalSupply = token.totalSupply().mul(41).div(59);
    
    // 12% of the total number of ONE tokens will be allocated to the team and SDK developers
    MintableToken(token).mint(walletTeam, newTotalSupply.mul(12).div(100));
    
    // 3% of the total number of ONE tokens will be allocated to professional fees and Bounties
    MintableToken(token).mint(walletAdvisers, newTotalSupply.mul(3).div(100));
    
    // 15% of the total number of ONE tokens will be allocated to Protocol One founders
    MintableToken(token).mint(walletFounders, newTotalSupply.mul(15).div(100));
    
    // 10% of the total number of ONE tokens will be allocated to Protocol One,
    // and as a reserve for the company to be used for future strategic plans for the created ecosystem
    MintableToken(token).mint(walletReserve, newTotalSupply.mul(10).div(100));
  }
}

