// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;



contract LotteryLucky32 {

    address public immutable owner;
    string public gameName;
    string public description;
    uint256 public ticketPrice;
    uint256 private secretNumber;
    uint256 public winNumber;
    bool public isSecretNumberReveald;
    uint256 public ownerPercent;
    uint256 public deadLine;
    bool private locked;
    bool private pausedOnce;
    uint256 public pauseDeadLine;
    uint256 public MIN_TICKET_PRICE = 0.1 ether;
    uint256 public MAX_TICKET_PRICE = 1 ether;

    mapping(address => uint256) public playerLuckyNumber;
    address[] players;
    address[] winners;

    //Events
    event GameCreated(string _message, address owner, uint256 price, uint256 timeStamp);
    event GameStarted(string _message, uint256 timeStamp, uint256 deadLine);
    event GameIsPaused(string _message, uint256 daysPause, uint256 timeStamp);
    event GameIsUnPaused(string _message, uint256 timeStamp);
    event GameDeadLineChange(string _message, uint256 newDeadLine, uint256 timeStamp);
    event TicketPurches(string _message, address indexed player, uint256 timeStamp);
    event Refunded(string _message, address indexed player, uint256 timestamp);
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
        string memory _gameName,
        string memory _description,
        uint256 _ownerPercent,
        uint256 _ticketPrice,
        uint256 _deadLine
    ) {
        require(msg.sender != address(0), "Invalid address.");
        require(bytes(_gameName).length > 0, "Name should not be empty.");
        require(bytes(_description).length > 0, "Description should not be empty.");
        require(_ownerPercent >= 1 && _ownerPercent <= 10, "Owner percent should be between 1 and 10.");
        require(_ticketPrice >= MIN_TICKET_PRICE && _ticketPrice <= MAX_TICKET_PRICE, "Ticket price should be 0.1 ETH and less 1 ETH (In clussive).");
        require(_deadLine >= 1 && _deadLine <= 32, "Deadline should be no less then 1 day and no more then 32 days.");

        owner = msg.sender;
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

    function ShowTicketsSold() external view returns (uint256) {
        return players.length;
    }

    function revealWinNumber() internal returns (uint256) {
    require(msg.sender != address(0), "Invalid address.");
    require(isSecretNumberReveald == false, "Secret number is already revealeded.");
    secretNumber = uint256(keccak256(abi.encodePacked(
        block.difficulty,
        block.timestamp,
        block.prevrandao,
        owner
    )));
    winNumber = (secretNumber % 32) + 1;
    isSecretNumberReveald = true;
    emit RevealSecretNumber("Secret number is revealed.", winNumber, block.timestamp);
    return winNumber;
    }

    function showWinNumber() public view secretNumberMustBeRevealed returns (uint256) {
        return winNumber;
    } 

    function refund() external gameIsTerminated onlyMember {
        require(msg.sender != address(0), "Invalid address.");
        uint256 yourLuckyNumber = playerLuckyNumber[msg.sender];
        playerLuckyNumber[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: ticketPrice, gas: 50000}("");
        if (!success) {
            playerLuckyNumber[msg.sender] = yourLuckyNumber;
            revert("Transfer failed");
        } else {
            emit Refunded("Your tickets are refunded.", msg.sender, block.timestamp);
        }
    }

    function finishGame() external gameIsActive onlyMember noReentrace {
        require(block.timestamp > deadLine, "Deadline has not passed.");
        revealWinNumber();
        for (uint256 i = 0; i < players.length; i++) {
            address player = players[i];
            if (playerLuckyNumber[player] == winNumber) {
                winners.push(player);
            }
        }

        if(winners.length == 0) {
            gameStatus = GameStatus.TERMINATED;
            emit GameFinishNoWinners("There is no winners in this game. Game is terminated. You can refund.", block.timestamp);
        }
        require(winners.length > 0, "There is no winners.");
        gameStatus = GameStatus.FINISHED;
        uint256 percentToOwner = (address(this).balance/100) * ownerPercent;
        (bool success, ) = owner.call{value: percentToOwner, gas: 50000}("");
        if (!success) {
            revert("Transfer failed");
        }
        uint256 percentToWinners = address(this).balance / winners.length;
        for (uint256 i = 0; i < winners.length; i++) {
            uint256 yourLuckyNumber = playerLuckyNumber[winners[i]];
            playerLuckyNumber[winners[i]] = 0;
            (bool success2, ) = winners[i].call{value: percentToWinners, gas: 50000}("");
            if (!success2) {
                playerLuckyNumber[winners[i]] = yourLuckyNumber;
                continue;
            }
        }
    }
}