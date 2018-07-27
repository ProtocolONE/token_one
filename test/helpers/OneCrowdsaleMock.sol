pragma solidity ^0.4.18;


import '../../contracts/OneCrowdsale.sol';

// mock class using PreSaleCrowdsale
contract OneCrowdsaleMock is OneCrowdsale {

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
}