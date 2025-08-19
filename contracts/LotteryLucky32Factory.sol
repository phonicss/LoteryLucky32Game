// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./LotteryLucky32.sol";

contract LotteryLucky32Factory {

    address[] public deployedLotteries;
    address public owner; 

    //Events
    event LotteryCreated( address indexed _lotteryAddress,
     address _owner,
     string _gameName,
     string _description,
     uint256 _ownerPercent,
     uint256 _ticketPrice,
     uint256 _deadLine );

    constructor() {
        owner = msg.sender;
    }

    function createLottery(
        address _owner,
        string memory _gameName,
        string memory _description,
        uint256 _ownerPercent,
        uint256 _ticketPrice,
        uint256 _deadLine
    ) external returns (address) {
        require(msg.sender == owner, "Only owner can create new lottery.");
        LotteryLucky32 newLottery = new LotteryLucky32(_owner, _gameName, _description, _ownerPercent, _ticketPrice, _deadLine);
        deployedLotteries.push(address(newLottery));
        emit LotteryCreated(address(newLottery), _owner, _gameName, _description, _ownerPercent, _ticketPrice, _deadLine);
        return address(newLottery);
    }

    function getDeployedLotteries() external view returns(address[] memory) {
        return deployedLotteries;
    }

    function showOwner() external view returns(address) {
        return owner;
    }

}