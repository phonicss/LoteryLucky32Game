// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LotteryLucky32 is VRFConsumerBase {

    bytes32 internal keyHash; // id Oracle
    uint256 internal fee;     // fee in LINK
    uint256 public randomResult;

    address public immutable owner;
    string public gameName;
    string public description;
    uint256 public ticketPrice;
    uint256 private secretNumber;
    uint256 public winNumber;
    bool public isSecretNumberReveald;
    uint256 public ownerPercent;
    uint256 public percentToWinners;
    uint256 public deadLine;
    bool private locked;
    bool private pausedOnce;
    uint256 public pauseDeadLine;
    uint256 public constant MIN_TICKET_PRICE = 0.01 ether; // 0.01 MATIC
    uint256 public constant MAX_TICKET_PRICE = 100 ether; // 100 MATIC


    //Mapping player's address to the number betwen 1 - 32
    mapping(address => uint256) public playerLuckyNumber;
    //Array of player's addresses
    address[] players;
    //Array of winners
    address[] winners;

    //Events
    event GameCreated(string _message, address owner, uint256 price, uint256 timeStamp);
    event GameStarted(string _message, uint256 timeStamp, uint256 deadLine);
    event GameIsPaused(string _message, uint256 daysPause, uint256 timeStamp);
    event GameIsUnPaused(string _message, uint256 timeStamp);
    event GameDeadLineChange(string _message, uint256 newDeadLine, uint256 timeStamp);
    event TicketPurches(string _message, address indexed player, uint256 timeStamp);
    event Refunded(string _message, address indexed player, uint256 timestamp);
    event PrizeClaimed(string _message, address indexed player, uint256 timestamp);
    event RevealSecretNumber(string _message, uint256 secretNumber, uint256 timeStamp);
    event GameFinishNoWinners(string _message, uint256 timeStamp);

    //Enum. Game statuses. 
    enum GameStatus {INACTIVE, ACTIVE, PAUSED, FINISHED, TERMINATED}
    GameStatus gameStatus;

    //Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner.");
        _;
    }

    modifier noReentrace() {
        require(!locked, "Reentrance detected.");
        locked = true;
        _;
        locked = false; 
    }

    modifier gameIsActive() {
        require(gameStatus == GameStatus.ACTIVE, "Game is not ACTIVE.");
        _;
    }

    modifier gameIsInactive() {
        require(gameStatus == GameStatus.INACTIVE, "Game should be Inactive.");
        _;
    }

     modifier gameIsPaused() {
        require(gameStatus == GameStatus.PAUSED, "Game is not PAUSED.");
        _;
    }

    //Game could be paused only once
    modifier gameCouldBePausedOnce() {
        require(pausedOnce == false, "Game can be paused only once.");
        _;
    }

    modifier gameIsTerminated() {
        require(gameStatus == GameStatus.TERMINATED, "Game is not TERMINATED.");
        _;
    }

    modifier gameIsFinished() {
        require(gameStatus == GameStatus.FINISHED, "Game is not FINISHED.");
        _;
    }

    modifier onlyMember() {
        require(playerLuckyNumber[msg.sender] != 0 || msg.sender == owner, "Only players or owner.");
        _;
    }

    modifier secretNumberMustBeRevealed() {
        require(isSecretNumberReveald == true, "Secret number must be reveladed first.");
        _;
    }

    constructor(
        address _owner,
        string memory _gameName,
        string memory _description,
        uint256 _ownerPercent,
        uint256 _ticketPrice,
        uint256 _deadLine
    ) 
        VRFConsumerBase( 0xAE975071Be8F8eE67addBC1A82488F1C24858067, // VRF Coordinator (Polygon)
        0xb0897686c545045aFc77CF20eC7A532E3120E0F1  // LINK Token (Polygon)
        ) {
            keyHash = 0xd729dc84e21ae57ffb6be0053bf2b0668aa2aaf300a2a7b2ddf7dc0bb6e875a8; // KeyHash (Polygon);
            fee = fee = 0.0005 * 10**18; // 0.0005 LINK

        require(msg.sender != address(0), "Invalid address.");
        require(bytes(_gameName).length > 0, "Name should not be empty.");
        require(bytes(_description).length > 0, "Description should not be empty.");
        require(_ownerPercent >= 1 && _ownerPercent <= 10, "Owner percent should be between 1 and 10.");
        //require(_ticketPrice >= MIN_TICKET_PRICE && _ticketPrice <= MAX_TICKET_PRICE, "Ticket price should be 0.01 MATIC and less 1 MATIC (In clussive).");
        require(_deadLine >= 1 && _deadLine <= 32, "Deadline should be no less then 1 day and no more then 32 days.");

        owner = _owner;
        gameName = _gameName;
        description = _description;
        ownerPercent = _ownerPercent;
        ticketPrice = _ticketPrice;
        deadLine = block.timestamp + (_deadLine * 1 days);
        pausedOnce = false;
        
        gameStatus = GameStatus.INACTIVE;
        
        //Emit event
        emit GameCreated("Game has been created. But not started yet.", owner, ticketPrice, block.timestamp);
        
    }



    function startGame() public onlyOwner gameIsInactive {
        require(gameStatus == GameStatus.INACTIVE, "Game should be inactive to start.");
        gameStatus = GameStatus.ACTIVE;
        emit GameStarted("Game hasstarted", block.timestamp, deadLine);
    }

    /**************************************************************************/
    /****************************** PAUSE AND UNPAUSE GAME ********************/
    /**************************************************************************/

    function gamePause(uint256 daysPaused) public onlyOwner gameCouldBePausedOnce {
        require(daysPaused >= 1 && daysPaused <= 3, "Days paused should be between 1 and 3.");
        gameStatus = GameStatus.PAUSED;
        pausedOnce = true;
        pauseDeadLine = block.timestamp + (daysPaused * 1 days);
        deadLine = deadLine + (daysPaused * 1 days);
        emit GameIsPaused("Game is paused", daysPaused, block.timestamp);
        emit GameDeadLineChange("Game deadline is extended", deadLine, block.timestamp);
        
    }

    function gameUnPause() public onlyMember gameIsPaused {
        require(pauseDeadLine < block.timestamp, "Pause deadline has not passed.");
        gameStatus = GameStatus.ACTIVE;
        emit GameIsUnPaused("Game is unpaused", block.timestamp);
    }

    /**************************************************************************/
    /****************************** EXTEND AND TERMINATE GAME *****************/
    /**************************************************************************/

    function extendDeadLine(uint daysToExtend) public onlyOwner gameIsPaused {
        uint256 newDeadLine = deadLine + (daysToExtend * 1 days);
        require(newDeadLine > block.timestamp, "New deadline should be in the future.");
        deadLine = newDeadLine;
        emit GameDeadLineChange("Game deadline is extended", deadLine, block.timestamp);
    }

    function terminateGame() public onlyOwner {
        require(block.timestamp < deadLine, "Deadline is already passed.");
        gameStatus = GameStatus.TERMINATED;
    }

    function showBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**************************************************************************/
    /****************************** BUY TICKET AND OPTIONS ********************/
    /**************************************************************************/

    function buyTicket(uint256 myNumber) external payable noReentrace gameIsActive {
        //Check requirments 
        require(msg.sender != address(0), "Address is not valid.");
        require(playerLuckyNumber[msg.sender] == 0, "You already have a ticket.");
        require(myNumber >= 1 && myNumber <= 32, "Number should be between 1 and 32.");
        require(deadLine > block.timestamp, "Deadline has passed.");
        require(msg.value == ticketPrice, "Price should be equal to ticket price.");
        playerLuckyNumber[msg.sender] = myNumber;
        players.push(msg.sender);
        emit TicketPurches("Ticket has been purchesd.", msg.sender, block.timestamp);  
    }

    function showMyTicket() external onlyMember view returns (uint256) {
        return playerLuckyNumber[msg.sender];
    }

    function showTicketsSold() external view returns (uint256) {
        return players.length;
    }

    function showCurrentGameStatus() external view returns (GameStatus) {
        return gameStatus;
    }


    /************************MAIN LOGIC*****************************************/
    /************************ORACLE Chainlink VRF to get Random number*********/
    /************************GENERATE AND REVEAL WIN NUMBER ******************/
    /*********PAY PERCENT TO OWNER IF THERE IS ATLEST ONE WINNER*************/

    //This function request random number from Chainlink VRF
    function requestRandomNumber() public returns (bytes32 requestId) {
    require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
    return requestRandomness(keyHash, fee);
    }

    //This function is called by Chainlink VRF Coordinator only
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(isSecretNumberReveald == false, "Secret number is already revealeded.");
        isSecretNumberReveald = true;
        randomResult = randomness;
        winNumber = (randomResult % 32) + 1; // generate random number from 1 to 32
        
        emit RevealSecretNumber("Secret number is revealed.", winNumber, block.timestamp);
            
        // Determine the winners
        for (uint256 i = 0; i < players.length; i++) {
            if (playerLuckyNumber[players[i]] == winNumber) {
                winners.push(players[i]);
            }
        }

        if (winners.length == 0) {
            gameStatus = GameStatus.TERMINATED;
            emit GameFinishNoWinners("No winners. Game terminated.", block.timestamp);
        } else {
            gameStatus = GameStatus.FINISHED;
            uint256 percentToOwner = (address(this).balance/100) * ownerPercent;
            (bool success, ) = owner.call{value: percentToOwner}("");
            if (!success) {
                revert("Transfer failed");
            }

            percentToWinners = address(this).balance / winners.length;
            
        }

    }

    //FINISH GAME
    function finishGame() external gameIsActive onlyMember noReentrace {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        require(block.timestamp > deadLine, "Deadline not passed.");
        require(!isSecretNumberReveald, "Already revealed");
        requestRandomNumber();
       
    }

    //Show win number
    function showWinNumber() public view secretNumberMustBeRevealed returns (uint256) {
        return winNumber;
    } 

    /*****************REFUND IF GAME TERMINATED OR NO WINNERS*************/
    /*****************CLAIM YOUR PRIZE IF YOU WON************************/
    /*****************CLAIM UNUSED LINK*********************************/

    function refund() external gameIsTerminated onlyMember {
        require(msg.sender != address(0), "Invalid address.");
        require(playerLuckyNumber[msg.sender] != 0, "Balance is empty");
        uint256 yourLuckyNumber = playerLuckyNumber[msg.sender];
        playerLuckyNumber[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: ticketPrice}("");
        if (!success) {
            playerLuckyNumber[msg.sender] = yourLuckyNumber;
            revert("Transfer failed.");
        } else {
            emit Refunded("Your tickets are refunded.", msg.sender, block.timestamp);
        }
    }

    function claimPrize() external gameIsFinished onlyMember {
        require(msg.sender != address(0), "Invalid address.");
        require(playerLuckyNumber[msg.sender] == winNumber, "You are not a winner.");
        uint256 yourLuckyNumber = playerLuckyNumber[msg.sender];
        playerLuckyNumber[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: percentToWinners}("");
        if(!success) {
            playerLuckyNumber[msg.sender] = yourLuckyNumber;
            revert("Transfer failed.");
        } else {
            emit PrizeClaimed("Prize claimed by winner,", msg.sender, block.timestamp);
        }
    }

    //Withdraw the rest of LINK
    function withdrawLINK() external onlyOwner {
        IERC20 linkToken = IERC20(0xb0897686c545045aFc77CF20eC7A532E3120E0F1);
        bool success = linkToken.transfer(owner, linkToken.balanceOf(address(this)));
        require(success, "LINK transfer failed");
    }
  
}