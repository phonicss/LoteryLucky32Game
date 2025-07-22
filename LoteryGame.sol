// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Lottery {

    address public immutable owner;
    string public gameName;
    string public description;
    uint256 public ticketPrice;
    uint256 public numbersOfSlots;
    uint256[] private winNumbers;
    uint256 public deadLine;
    bool private locked;

    struct PlayerTickets {
        uint256[][] ticketsNumbers;
        uint256 numberOfTickets;
        bool isWinner;
    }

    mapping(address => PlayerTickets) public players;
    address[] winners;

    //Events
    event GameCreated(string _message, address owner, uint256 price, uint256 timeStamp);
    event GameStarted(string _message, uint256 timeStamp, uint256 deadLine);
    event TicketPurches(string _message, address indexed player, uint256 timeStamp);
    event Refunded(string _message, address indexed player, uint256 timestamp);

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

     modifier gameIsPaused() {
        require(gameStatus == GameStatus.PAUSED, "Game is not PAUSED.");
        _;
    }

    modifier gameIsTerminated() {
        require(gameStatus == GameStatus.TERMINATED, "Game is not TERMINATED.");
        _;
    }

    constructor(
        string memory _gameName,
        string memory _description,
        uint256 _numbersOfSlots,
        uint256 _ticketPrice
    ) {
        require(msg.sender != address(0), "Invalid address.");
        require(bytes(_gameName).length > 0, "Name should not be empty.");
        require(bytes(_description).length > 0, "Description should not be empty.");
        require(_numbersOfSlots >= 3 && _numbersOfSlots <= 10, "Numbers should be between 3 and 10 (inclusive).");
        require(_ticketPrice >= 100000000000000000, "Ticket price should be 0.1 ETH or more.");
        
        owner = msg.sender;
        gameName = _gameName;
        description = _description;
        ticketPrice = _ticketPrice;
        numbersOfSlots = _numbersOfSlots;
        gameStatus = GameStatus.INACTIVE;
        
        //Emit event
        emit GameCreated("Game has been created. But not started yet.", owner, ticketPrice, block.timestamp);
        
    }

    function startGame(uint256 daysOfLotery, uint256[] memory _winNumbers) public onlyOwner {
        //set deadline for the lotery
        require(gameStatus == GameStatus.INACTIVE, "Game should be inactive to start.");
        require(daysOfLotery >= 1 && daysOfLotery <= 30, "Deadline should be betwen 1 and 30 days (inclusive).");
        require(_winNumbers.length == numbersOfSlots, "Win numbers should be equal to preset of numbers of slots.");
        deadLine = block.timestamp + (daysOfLotery * 1 days);
        gameStatus = GameStatus.ACTIVE;
        winNumbers = _winNumbers;
        
        emit GameStarted("Game hasstarted", block.timestamp, deadLine);
    }

    function gamePause() public onlyOwner gameIsActive {
        gameStatus = GameStatus.PAUSED;
    }

    function gameUnPause() public onlyOwner gameIsPaused {
        gameStatus = GameStatus.ACTIVE;
    }

    function extendDeadLine(uint daysToExtend) public onlyOwner gameIsPaused {
        uint256 newDeadLine = deadLine + (daysToExtend * 1 days);
        require(newDeadLine > block.timestamp, "New deadline should be in the future.");
        deadLine = newDeadLine;
    }

    function terminateGame() public onlyOwner {
        require(block.timestamp < deadLine, "Deadline is already passed.");
        gameStatus = GameStatus.TERMINATED;
    }

    function showBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function buyTicket(uint256[] memory  yourNumbers) external payable noReentrace gameIsActive {
        //Check requirments 
        require(yourNumbers.length == numbersOfSlots, "Numbers shoud be equal to number of slots.");
        require(deadLine > block.timestamp, "Deadline has passed.");
        require(msg.sender != address(0));
        require(msg.value == ticketPrice, "Price should be equal to ticket price.");
        PlayerTickets storage player = players[msg.sender];
        require(player.numberOfTickets < 10, "You can buy up to 10 tickets");

        //check if your numbers equal to win numbers
        if (!player.isWinner) {
            bool allNumbersMatch = true;
            for (uint256 i = 0; i < yourNumbers.length; i++) {
                if (yourNumbers[i] != winNumbers[i]) {
                    allNumbersMatch = false;
                    break;
                }    
            }
            if (allNumbersMatch) {
                player.isWinner = true;
                winners.push(msg.sender);
            }           
        }

        player.ticketsNumbers.push(yourNumbers);
        player.numberOfTickets++;
        emit TicketPurches("Ticket has been purchesd", msg.sender, block.timestamp);  
    }

    function showMyTickets() external view returns (uint256[][] memory) {
        PlayerTickets storage player = players[msg.sender];
        return player.ticketsNumbers;
    }

    function refund() public gameIsTerminated {
        require(msg.sender != address(0), "Invalid address.");
        uint256 myTickets = players[msg.sender].numberOfTickets;
        players[msg.sender].numberOfTickets = 0;
        (bool success, ) = msg.sender.call{value: myTickets*ticketPrice, gas: 10000}("");
        if (!success) {
            players[msg.sender].numberOfTickets = myTickets;
            revert("Transfer failed");
        } else {
            emit Refunded("Your tickets are refunded.", msg.sender, block.timestamp);
        }
    }


}













