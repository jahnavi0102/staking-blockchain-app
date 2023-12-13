// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Stakings is Ownable {

    using SafeMath for uint256;

    IERC20 public token;

    struct StakeInfo {
        uint256 interest;
        uint256 balance;
        uint256 depositTime;
        uint256 reward;
        bool withdraw;
    }
    
    uint256 constant DefaultPlan = 0;
    uint256 constant DaysOf7Plan = 7;
    uint256 constant DaysOf30Plan = 30;
    uint256 constant DaysOf90Plan = 90;

    struct WithdrawRequest {
        address walletAddress;
        uint256 amount;
        string chainLink;
    }
    // update withdraw can have multiple orders 
    mapping(address => WithdrawRequest) public WithdrawRequests;

    mapping(address => mapping(uint256 => StakeInfo[])) public stakers;
    uint256 constant SEC_OF_7_DAYS = 604800;
    uint256 constant SEC_OF_30_DAYS = 2592000;
    uint256 constant SEC_OF_90_DAYS = 7776000;
    uint256 constant NO_OF_DAYS_IN_A_YEAR = 31536000;

    constructor(address _initialOwner) Ownable(_initialOwner)  {
        token = IERC20(_initialOwner);
    }

    function getReward(uint256 amount, uint256 no_of_days, uint256 interest) public pure returns (uint256) {
        if (interest == DefaultPlan){
            return amount.mul(interest).mul(no_of_days).div(NO_OF_DAYS_IN_A_YEAR);
        }
        else {
            return amount.mul(interest);
        }
            
    }


    function staking(address userAddress, uint256 amount, uint256 interest) external payable {
        require(userAddress == msg.sender, "Not Authorized");
        require(amount > 0, "Amount must be greater than 0");

        if (interest == DefaultPlan){
            if (stakers[msg.sender][interest].length > 0) {
            uint256 reward = getReward(stakers[msg.sender][interest][0].balance, block.timestamp - stakers[msg.sender][interest][0].depositTime, interest);
            stakers[msg.sender][interest][0].balance = stakers[msg.sender][interest][0].balance.add(reward).add(amount);
            } else {
                stakers[msg.sender][interest][0].balance = amount;
            }

            stakers[msg.sender][interest][0].depositTime = block.timestamp;
        }
        else {
            StakeInfo memory newStake = StakeInfo({
            interest: interest,
            balance: amount,
            depositTime: block.timestamp,
            reward: 0,
            withdraw: true
        });
            stakers[msg.sender][interest].push(newStake);
        }
    

        token.transferFrom(msg.sender, owner(), amount);

        
    }

    function withdraw(address userAddress, string memory _chainLink, uint256 interest) external payable {
        // TODO: one address can have multiple
        require(userAddress == msg.sender, "Not Authorized");
        require(stakers[msg.sender][interest].length > 0, "No plans exist");
        require(interest == DefaultPlan || interest == DaysOf7Plan || interest == DaysOf30Plan || interest == DaysOf90Plan, "plan doesn't exist");

        if (interest == DefaultPlan){
            uint256 reward = getReward(stakers[msg.sender][interest][0].balance, block.timestamp - stakers[msg.sender][interest][0].depositTime, interest);
            WithdrawRequests[msg.sender].amount =  stakers[msg.sender][interest][0].balance.add(reward);
            WithdrawRequests[msg.sender].walletAddress = msg.sender;
            WithdrawRequests[msg.sender].chainLink = _chainLink;
            stakers[msg.sender][interest].pop();
        }
        else {
            require(block.timestamp.sub(stakers[msg.sender][interest][0].depositTime)>=0);
            uint256 reward = getReward(stakers[msg.sender][interest][0].balance, 0, interest);
            WithdrawRequests[msg.sender].amount =  stakers[msg.sender][interest][0].balance.add(reward);
            WithdrawRequests[msg.sender].walletAddress = msg.sender;
            WithdrawRequests[msg.sender].chainLink = _chainLink;
            stakers[msg.sender][interest].pop();
        }
    }

    function getWithdrawLinst(address UserAdress) external onlyOwner view returns(mapping(address => WithdrawRequest)) {
        // TODO: MUTIPLE USERS ACCOUNT HANDLE
        return WithdrawRequests ;
    }
}
