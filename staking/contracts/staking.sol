// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Stakings is Ownable {

    using SafeMath for uint256;

    address public ownerAddress;
    IERC20 public token;

    struct StakeInfo {
        uint256 plan;
        uint256 depositTime;
        uint256 balance;
        uint256 reward;
    }

    mapping(address => StakeInfo) public stakers;

    uint256 public constant DAYS_7_IN_SECONDS = 604800;
    uint256 public constant DAYS_30_IN_SECONDS = 2592000;
    uint256 public constant DAYS_90_IN_SECONDS = 7776000;


    constructor(address _initialOwner) Ownable(_initialOwner)  {
        ownerAddress = _initialOwner;
        token = IERC20(_initialOwner);
    }

    function staking(uint256 amount) external {
        StakeInfo storage staker = stakers[msg.sender];
        address from = msg.sender;

        if (staker.balance > 0 && staker.reward > 0) {
            token.transferFrom(from, ownerAddress, amount);
            staker.balance = staker.balance.add(amount);
        }
        else {
            token.transferFrom(from, ownerAddress, amount); 
            staker.balance = amount;
            staker.depositTime = block.timestamp;
        }
    }




}