pragma solidity ^0.4.18;


import '../../contracts/OneCrowdsale.sol';

// mock class using PreSaleCrowdsale
contract OneCrowdsaleMock is OneCrowdsale {

  event SendDealDepositData(
    address refundWallet,
    uint256 depositedETH,
    uint256 depositedTokens,
    uint256 transferred
  );

  function OneCrowdsaleMock(address _wallet, address _walletTeam, address _walletAdvisers, 
    address _walletOperating, address _walletReserve, address _walletBounty, uint256 _openingTime, uint256 _closingTime,
    uint256 _softCap, uint256 _hardCap) 
  public
  OneCrowdsale(_wallet, 
                   _walletTeam,
                   _walletAdvisers,
                   _walletOperating,
                   _walletReserve,
                   _walletBounty,
                   _openingTime,
                   _closingTime,
                   _softCap,
                   _hardCap) {
  
  }

  function addDepositMock(address _refundWallet,
                          address _wallet,
                          uint256 _wei,
                          uint256 _tokens) {
    addDeposit(_refundWallet, _wallet, _wei, _tokens);
  }

  function getBonusRateMocked(address _benefic) public view returns (uint256) {
    uint256 bRate = getBonusRate(_benefic);
    return bRate;
  }

  function getWalletRefundData(address _wallet) {
      DealDeposit storage deposit = depositMap[_wallet];

      emit SendDealDepositData(
          deposit.refundWallet,
          deposit.depositedETH,
          deposit.depositedTokens,
          deposit.transferred
      );
  }

  function setDepositTokens(address _wallet, uint256 _tokens) {
    if (depositMap[_wallet].refundWallet == address(0)) {
        return;
    }

    DealDeposit storage deposit = depositMap[_wallet];
    deposit.depositedTokens = _tokens;
  }

  function setMainCliffAmount(address _wallet, uint256 _amount) {
    DepositTimeLock storage timeLock = depositTimeLockMap[_wallet];
    timeLock.mainCliffAmount = _amount;
  }

  function setDepositTransferred(address _wallet, uint256 _amount) {
    DealDeposit storage deposit = depositMap[_wallet];
    deposit.transferred = _amount;
  }

  function setDepositedETH(address _wallet, uint256 _amount) {
    DealDeposit storage deposit = depositMap[_wallet];
    deposit.depositedETH = _amount;
  }

  function getFinalizedTime() constant public returns (uint256) {
    return finalizedTime;
  }

  function getNow() constant public returns (uint256) {
    return now;
  }
}