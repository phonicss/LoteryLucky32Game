const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Lottery Lucky 32 System", function() {
    let lottery, factory;
    let deployer, owner, player1, player2;

    before(async function() {
        // getting all accounts
        [deployer, owner, player1, player2] = await ethers.getSigners();
        
        // deploy by owner
        const Factory = await ethers.getContractFactory("LotteryLucky32Factory");
        factory = await Factory.connect(owner).deploy();
        let ownerAddress = await factory.showOwner();
        console.log(`Factory.owner is: ${ownerAddress}`);
        console.log(`AND deploy owner is: ${owner.address}`);
        
        
        // creating lottery by owner
        await factory.connect(owner).createLottery(
            ownerAddress,
            "Test lottery", 
            "Description test", 
            5, 
            ethers.parseEther("0.1"), 
            7
        );
        
        // getting address of the lottery contract and ABI
        const lotteries = await factory.getDeployedLotteries();
        lottery = await ethers.getContractAt("LotteryLucky32", lotteries[0]);
        console.log(`lottery address is: ${lottery}`);
    });


    describe("Deploy", () => {
        it("Should have correct owner set", async function() {
                expect(await factory.owner()).to.equal(owner.address);
                const info = await lottery.owner();
                console.log(`Lottery owner is: ${info}`)
                console.log(`but the owner is: ${owner.address}`)
                
            });
    })

    describe("Start game", () => {
        it("Should allow the owner to start the game", async function() {
        // Checking the status
        expect(await lottery.showCurrentGameStatus()).to.equal(0); // 0 = INACTIVE
        
        // Start the lottery game by owner
        await lottery.connect(owner).startGame();
        
        // Checking new status
        expect(await lottery.showCurrentGameStatus()).to.equal(1); // 1 = ACTIVE
        }); 
    })

    describe("Pause unpause Game", () => {
        it("Should allow the owner to pause and unpause the game", async function () {
        await lottery.connect(owner).gamePause(1);
        expect(await lottery.showCurrentGameStatus()).to.equal(2); // 2 = PAUSED

        //change time to 1 day later (86400 seconds)
        await network.provider.send("evm_increaseTime", [86400]);
        await network.provider.send("evm_mine"); // creating new block

        await lottery.connect(owner).gameUnPause();
        expect(await lottery.showCurrentGameStatus()).to.equal(1); // 1 = ACTIVE

        //Trying to pouse the game once more time
        expect(lottery.connect(owner).gamePause(1)).to.be.revertedWith("");
        })

        it("Should allow to pause the game only once", async function() {
            expect(lottery.connect(owner).gamePause(1)).to.be.revertedWith("");
        })
    })

     describe("Player buy a ticket", () => {
        it("Should allow player to buy a ticket", async function() {
            expect(lottery.connect(player1).buyTicket(33)).to.be.rejectedWith("");
            expect(lottery.connect(player1).buyTicket(-1)).to.be.rejectedWith("");
            expect(lottery.connect(player1).buyTicket(25,{ value: ethers.parseEther("1.0")})).to.be.rejectedWith("");
        })
    })

    describe("Game termination", () => {
        it("Should allow owner to terminate the game if deadline is not passed", async function() {
        expect(lottery.connect(owner).terminateGame()).to.be.rejectedWith("");
        expect(await lottery.showCurrentGameStatus()).to.not.equal(4);
        await network.provider.send("evm_increaseTime", [86400]); // change time
        await network.provider.send("evm_mine"); //create new block
        await lottery.connect(owner).terminateGame();
        expect(await lottery.showCurrentGameStatus()).to.equal(4); // 4 = TERMINATED
        })
    })

    describe("Refund", () => {
        it("Should allowed player to refund", async function() {
            
            expect(lottery.connect(player1).refund());
        })
    })

   
  

   

    

    

   





});











