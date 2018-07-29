pragma solidity ^0.4.18;
import "./Defcon.sol";
import "./SafeMath.sol";

contract bigBankLittleBank is DefconPro {
    
    using SafeMath for uint;
    
    uint public houseFee = 2; //2%
    uint public houseCommission = 0;
    uint public bookKeeper = 0;
    
    event BigBankBet(uint blockNumber, address indexed winner, address indexed loser, uint winningBetId1, uint losingBetId2, uint total);
    event Deposit(address indexed user, uint amount);
    event Withdraw(address indexed user, uint amount);
    
    //Main listing struct to hinge everything on
    BetBank[] private betBanks;
    
    //Listing Struct
    struct BetBank {
        uint bet;
        address owner;
    }

    function userBalance() public view returns(uint) {
        return userBank[msg.sender];
    }
    
    //setting up internal bank struct, should prevent prying eyes from seeing other users banks
    mapping (address => uint) public userBank;

    //empty public payable function lets users add to their bank without triggering a normal function
    function depositBank() public defcon4 payable {
        if(userBank[msg.sender] == 0) {
            userBank[msg.sender] = msg.value;
        } else {
            userBank[msg.sender] = (userBank[msg.sender]).add(msg.value);
        }
        bookKeeper = bookKeeper.add(msg.value);
        Deposit(msg.sender, msg.value);
    }
    
    //widthdraw what is in users bank
    function withdrawBank(uint amount) public defcon2 returns(bool) {
        require(userBank[msg.sender] >= amount);
        bookKeeper = bookKeeper.sub(amount);
        userBank[msg.sender] = userBank[msg.sender].sub(amount);
        Withdraw(msg.sender, amount);
        (msg.sender).transfer(amount);
        return true;
    }
    
    function startBet(uint _bet) public defcon3 returns(uint betId) {
        require(userBank[msg.sender] >= _bet);
        userBank[msg.sender] = (userBank[msg.sender]).sub(_bet);
        BetBank memory betBank = BetBank({
            bet: _bet,
            owner: msg.sender
        });
        //push new bet and get betId
        betId = betBanks.push(betBank).sub(1);
    }
   
    function _endBetListing(uint betId) private returns(bool){
        //betBanks[betId].bet = 0;
        delete betBanks[betId];
    }
    
    function betAgainstUser(uint _betId1, uint _betId2) public defcon3 returns(bool){
        require(betBanks[_betId1].bet > 0 && betBanks[_betId2].bet > 0);
        require(betBanks[_betId1].owner == msg.sender || betBanks[_betId2].owner == msg.sender); 
        require(betBanks[_betId1].owner != betBanks[_betId2].owner);//dissable for testing, prevent user from betting himself
        require(_betId1 != _betId2);
        uint take = (betBanks[_betId1].bet).add(betBanks[_betId2].bet);
        uint fee = (take.mul(houseFee)).div(100);
        houseCommission = houseCommission.add(fee);
        if(betBanks[_betId1].bet != betBanks[_betId2].bet) {
            if(betBanks[_betId1].bet > betBanks[_betId2].bet) {
                _payoutWinner(_betId1, _betId2, take, fee);
            } else {
                _payoutWinner(_betId2, _betId1, take, fee);
            }
        } else {
            if(_random() == 0) {
                _payoutWinner(_betId1, _betId2, take, fee);
            } else {
                _payoutWinner(_betId2, _betId1, take, fee);
            }
        }
        return true;
    }
    
    function triggerEvent()public returns(bool){
        BigBankBet(block.number, msg.sender, msg.sender, 69, 69, 1234);
    }

    function _payoutWinner(uint winner, uint loser, uint take, uint fee) private returns(bool) {
        BigBankBet(block.number, betBanks[winner].owner, betBanks[loser].owner, winner, loser, take.sub(fee));
        address winnerAddr = betBanks[winner].owner;
        _endBetListing(winner);
        _endBetListing(loser);
        userBank[winnerAddr] = (userBank[winnerAddr]).add(take.sub(fee));
        return true;
    }
    
    function setHouseFee(uint newFee)public onlyOwner returns(bool) {
        require(msg.sender == owner);
        houseFee = newFee;
        return true;
    }
    
    function withdrawCommission()public onlyOwner returns(bool) {
        require(msg.sender == owner);
        bookKeeper = bookKeeper.sub(houseCommission);
        uint holding = houseCommission;
        houseCommission = 0;
        owner.transfer(holding);
        return true;
    }
    
    function _random() private view returns (uint8) {
        return uint8(uint256(keccak256(block.timestamp, block.difficulty))%2);
    }
    
    function totalActiveBets() public view returns(uint total) {
        total = 0;
        for(uint i=0; i<betBanks.length; i++) {
            if(betBanks[i].bet > 0 && betBanks[i].owner != msg.sender) {
                total++;
            }
        }
    }
    
    function listActiveBets() public view returns(uint[]) {
        uint256 total = totalActiveBets();
        if (total == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](total);
            uint rc = 0;
            for (uint idx=0; idx < betBanks.length; idx++) {
                if(betBanks[idx].bet > 0 && betBanks[idx].owner != msg.sender) {
                    result[rc] = idx;
                    rc++;
                }
            }
        }
        return result;
    }
    
    function totalUsersBets() public view returns(uint total) {
        total = 0;
        for(uint i=0; i<betBanks.length; i++) {
            if(betBanks[i].owner == msg.sender && betBanks[i].bet > 0) {
                total++;
            }
        }
    }
    
    function listUsersBets() public view returns(uint[]) {
        uint256 total = totalUsersBets();
        if (total == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](total);
            uint rc = 0;
            for (uint idx=0; idx < betBanks.length; idx++) {
                if(betBanks[idx].owner == msg.sender && betBanks[idx].bet > 0) {
                    result[rc] = idx;
                    rc++;
                }
            }
        }
        return result;
    }
    
}