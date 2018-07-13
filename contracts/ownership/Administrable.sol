pragma solidity ^0.4.24;

import "./Ownable.sol";
import "../math/SafeMath.sol";

contract Administrable is Ownable {
  using SafeMath for uint256;

  address[] public adminsForIndex;
  mapping (address => bool) public admins;
  mapping (address => bool) private processedAdmin;

  event AddAdmin(address indexed admin);
  event RemoveAdmin(address indexed admin);

  modifier onlyAdmins {
    if (msg.sender != owner && !admins[msg.sender]) revert();
    _;
  }

  function totalAdminsMapping() public view returns (uint256) {
    return adminsForIndex.length;
  }

  function addAdmin(address admin) public onlyOwner {
    require(admin != address(0));
    admins[admin] = true;
    if (!processedAdmin[admin]) {
      adminsForIndex.push(admin);
      processedAdmin[admin] = true;
    }

    emit AddAdmin(admin);
  }

  function removeAdmin(address admin) public onlyOwner {
    require(admin != address(0));
    admins[admin] = false;

    emit RemoveAdmin(admin);
  }
}
