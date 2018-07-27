pragma solidity ^0.4.18;


import '../../contracts/crowdsale/PreSaleCrowdsale.sol';


// mock class using PreSaleCrowdsale
contract PreSaleCrowdsaleMock is PreSaleCrowdsale {

  event DeletePreSaleDealInvestorsMapKeysFound(uint256 index);

  function PreSaleCrowdsaleMock(uint256 _openingTime, uint256 _closingTime, uint256 _rate, uint256 _softCap, uint256 _hardCap) 
  public
  Crowdsale(_openingTime, _closingTime, _rate, _softCap, _hardCap) {
  
  }

  function setZeroAddressToInvestorWallet(address _wallet) {
    if (investorsMap[_wallet].wallet == address(0)) {
      return;
    }

    investorsMap[_wallet].wallet = address(0);
  }

  function deletePreSaleDeal(address _incomeWallet) external onlyAdmins onlyWhileOpen {
    require(investorsMap[_incomeWallet].wallet != address(0));

    delete investorsMap[_incomeWallet];

    uint256 index;
    for (uint256 i = 0; i < investorsMapKeys.length; i++) {
      if (investorsMapKeys[i] == _incomeWallet) {
        index = i;

        emit DeletePreSaleDealInvestorsMapKeysFound(index);
        break;
      }
    }

    investorsMapKeys[index] = investorsMapKeys[investorsMapKeys.length - 1];
    delete investorsMapKeys[investorsMapKeys.length - 1];
    investorsMapKeys.length--;

    emit InvestorDeleted(_incomeWallet);
  }
}