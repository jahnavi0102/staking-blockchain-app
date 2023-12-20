// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Stakings is Ownable {

    using SafeMath for uint256;

    IERC20 token;

    struct StakeInfo {
        uint256 balance;
        uint256 depositTime;
        bool withdraw;
    }
    mapping(address => StakeInfo) public defaultStakers;
    mapping(address => StakeInfo[]) public plan7Days;
    mapping(address => StakeInfo[]) public plan30Days;
    mapping(address => StakeInfo[]) public plan90Days;
    
    uint256 constant DefaultPlan = 0;
    uint256 constant DaysOf7Plan = 7;
    uint256 constant DaysOf30Plan = 30;
    uint256 constant DaysOf90Plan = 90;
    uint256 constant increment = 1;

    mapping(address => mapping(uint256 => uint256)) depositWithdrawTrack;

    struct WithdrawRequest {
        address walletAddress;
        uint256 amount;
        uint256 deposit;
        uint256 rewardEarned;
        uint256 plan;
        uint256 index;
        string chainLink;
    }
    uint256 constant withdrawRequestLength = 0;
    
    WithdrawRequest[] WithdrawRequests;

    uint256 constant SEC_OF_7_DAYS = 604800;
    uint256 constant SEC_OF_30_DAYS = 2592000;
    uint256 constant SEC_OF_90_DAYS = 7776000;

    uint256 constant NO_OF_DAYS_IN_A_YEAR = 365;

    constructor(address _initialOwner) Ownable(_initialOwner)  {
        token = IERC20(_initialOwner);
    }

    function getReward(uint256 amount, uint256 no_of_days, uint256 planNo) public pure returns (uint256) {
        if (planNo == DefaultPlan){
            return (amount.mul(planNo).mul(no_of_days)).div(NO_OF_DAYS_IN_A_YEAR.mul(100));
        }
        else {
            return (amount.mul(planNo)).div(100);
        }
            
    }


    function staking(address userAddress, uint256 amount, uint256 planNo) external payable {

        require(userAddress == msg.sender, "Not Authorized");
        require(amount > 0, "Amount must be greater than 0");
        require(planNo == DefaultPlan || planNo == DaysOf7Plan || planNo == DaysOf30Plan || planNo == DaysOf90Plan, "plan doesn't exist");


        if (planNo == DefaultPlan){
            if (defaultStakers[msg.sender].balance > 0) {
                uint noDays = (block.timestamp.sub(defaultStakers[msg.sender].depositTime)).div(60).div(60).div(24);
                uint256 reward = getReward(defaultStakers[msg.sender].balance, noDays, planNo);
                defaultStakers[msg.sender].balance = defaultStakers[msg.sender].balance.add(reward).add(amount);
            } else {
                defaultStakers[msg.sender].balance = amount;
            }
            defaultStakers[msg.sender].withdraw = true;
            defaultStakers[msg.sender].depositTime = block.timestamp;
        }
        else if (planNo == DaysOf7Plan) {
            StakeInfo memory newStake = StakeInfo({
                balance: amount,
                depositTime: block.timestamp,
                withdraw: false
            });
            plan7Days[msg.sender].push(newStake);
        }
        else if (planNo == DaysOf30Plan) {
            StakeInfo memory newStake = StakeInfo({
                balance: amount,
                depositTime: block.timestamp,
                withdraw: false
            });
            plan30Days[msg.sender].push(newStake);
        }
        else if (planNo == DaysOf90Plan) {
            StakeInfo memory newStake = StakeInfo({
                balance: amount,
                depositTime: block.timestamp,
                withdraw: false
            });
            plan90Days[msg.sender].push(newStake);
        }
        token.transferFrom(msg.sender, owner(), amount);
    }

    function withdraw(address userAddress, string calldata _chainLink, uint256 planNo) external payable {

        require(userAddress == msg.sender, "Not Authorized");
        require(planNo == DefaultPlan || planNo == DaysOf7Plan || planNo == DaysOf30Plan || planNo == DaysOf90Plan, "Plan doesn't exist");
        uint256 refundAmount;
        uint256 reward;
        StakeInfo memory userLoanInfo;
        uint256 timeSec = 0;
        uint256 index = 0;
        uint256 deposited;

        if (planNo == DefaultPlan){
            require(defaultStakers[msg.sender].withdraw == false, "Request sent for withdraw, will soon be added to your account");
            require(defaultStakers[msg.sender].balance > 0, "No amount to withdraw");
            userLoanInfo = defaultStakers[msg.sender];
            timeSec = block.timestamp - userLoanInfo.depositTime;
            defaultStakers[msg.sender].balance = 0;
            defaultStakers[msg.sender].withdraw = false;
            
        }
        else if (planNo == DaysOf7Plan) {
            require(block.timestamp.sub(plan7Days[msg.sender][depositWithdrawTrack[msg.sender][planNo]].depositTime)>=SEC_OF_7_DAYS, "Loan not matured");
            userLoanInfo = plan7Days[msg.sender][depositWithdrawTrack[msg.sender][planNo]];
            index = depositWithdrawTrack[msg.sender][planNo];
            depositWithdrawTrack[msg.sender][planNo] = depositWithdrawTrack[msg.sender][planNo].add(increment);
        }
        else if (planNo == DaysOf30Plan) {
            require(block.timestamp.sub(plan30Days[msg.sender][depositWithdrawTrack[msg.sender][planNo]].depositTime)>=SEC_OF_30_DAYS, "Loan not matured");
            userLoanInfo = plan30Days[msg.sender][depositWithdrawTrack[msg.sender][planNo]];
            index = depositWithdrawTrack[msg.sender][planNo];
            depositWithdrawTrack[msg.sender][planNo] = depositWithdrawTrack[msg.sender][planNo].add(increment);
        }
        else if (planNo == DaysOf90Plan) {
            require(block.timestamp.sub(plan90Days[msg.sender][depositWithdrawTrack[msg.sender][planNo]].depositTime)>=SEC_OF_90_DAYS,  "Loan not matured");
            userLoanInfo = plan7Days[msg.sender][depositWithdrawTrack[msg.sender][planNo]];
            index = depositWithdrawTrack[msg.sender][planNo];
            depositWithdrawTrack[msg.sender][planNo] = depositWithdrawTrack[msg.sender][planNo].add(increment);
        }

        deposited = userLoanInfo.balance;
        reward = getReward(deposited, timeSec, planNo);
        refundAmount = deposited.add(reward);
        WithdrawRequests.push(WithdrawRequest({
                walletAddress: msg.sender,
                amount: refundAmount,
                rewardEarned:reward,
                deposit: deposited,
                index: index,
                plan: planNo,
                chainLink: _chainLink
            }));
    }

    function getWithdrawLinst() external onlyOwner view returns(WithdrawRequest[] memory) {
        WithdrawRequest[] memory withdrawRequestTerminated = WithdrawRequests;
        delete withdrawRequestTerminated;
        return withdrawRequestTerminated ;
    }


    function getDetailsUserStakeInfo(address _address, uint256 planNo, uint256 index) external onlyOwner view returns(StakeInfo memory) {
        if (planNo == DefaultPlan) {
            return defaultStakers[_address];
        }
        else if (planNo == DaysOf7Plan){
            return plan7Days[_address][index];
        }
        else if (planNo == DaysOf30Plan){
            return plan30Days[_address][index];
        }
        else if (planNo == DaysOf90Plan){
            return plan90Days[_address][index];
        }
        else {
            revert("Invalid planNo"); // Add a revert statement for invalid planNo
        }
    }

}
