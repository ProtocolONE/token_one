pragma solidity ^0.4.19;

import "openzeppelin-solidity/contracts/crowdsale/validation/WhitelistedCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "./PoneCoin.sol";

contract PoneCoinCrowdsale is TimedCrowdsale, WhitelistedCrowdsale {

  address public walletTeam;
  address public walletOEM;
  address public walletBounties;
  address public walletReserve;

  struct MemberDescription {
    address _bonusPart;
    address _bonusCommission;
    uint256 _bonusPercent;
    uint256 _tokensToTransfer;
    uint256 _poneTokensToTransfer;
    string  _invoiceId;
    bool    kycFlag;
  }

  mapping (address => User) public customers;

  function PoneCoinCrowdsale(uint256 _openingTime, uint256 _closingTime, uint256 _rate, address _wallet, StandardToken _token) public
    Crowdsale(_rate, _wallet, _token)
    TimedCrowdsale(_openingTime, _closingTime)
  {
  }

  function requestOnCryptoTransfer(
                                 address _benefit,
                                 address _bonusPart,
                                 address _bonusCommission,
                                 uint256 _bonusPercent,
                                 uint256 _tokensToTransfer,
                                 uint256 _poneTokensToTransfer,
                                 bool kycFlag
                                )
  {
    // TODO validation
    addAddressToWhitelist(_benefit);
    customers[_benefit] = MemberDescription(_bonusPart, _bonusCommission, _bonusPercent, _tokensToTransfer, _poneTokensToTransfer, "", kycFlag);
  }

  function makeBonusPaymanet() {
    // process customer map
  }

  function requestOnInvoiceTransfer(
                                 address _benefit,
                                 address _bonusPart,
                                 uint256 _bonusPercent,
                                 uint256 _tokensToTransfer,
                                 string  _invoiceId,
                                 uint256 _poneTokensToTransfer,
                                 bool kycFlag
                                )
  {
    // TODO validation
    addAddressToWhitelist(_benefit);
    customers[_benefit] = MemberDescription(_bonusPart, 0, _bonusPercent, _tokensToTransfer, _poneTokensToTransfer, _invoiceId, kycFlag);
  }

  function deleteRestBonus() {
    // TODO
  }

  function stopTransactionAsap(address _addrToStop) {
    // TODO
  }

  // Add return list
  function getListOfNonKyc() {
    // TODO
    // Form list from map
  }

  function setKyc(address _addrToSetKyc) {
    
  }

}

