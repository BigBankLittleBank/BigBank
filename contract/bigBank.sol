pragma solidity ^0.4.18;
import "./Defcon.sol";
import "./SafeMath.sol";

contract bigBankLittleBank is DefconPro {
    
    using SafeMath for uint;
    
    uint public houseFee = 2; //Fee is 2%
    uint public houseCommission = 0; //keeps track of commission
    uint public bookKeeper = 0; //keeping track of what the balance should be to tie into auto pause script if it doesn't match contracte balance
    
    bytes32 emptyBet = 0x0000000000000000000000000000000000000000000000000000000000000000;
    
    //main event, listing off winners/losers
    event BigBankBet(uint blockNumber, address indexed winner, address indexed loser, uint winningBetId1, uint losingBetId2, uint total);
    //event to show users deposit history
    event Deposit(address indexed user, uint amount);
    //event to show users withdraw history
    event Withdraw(address indexed user, uint amount);
    
    //Private struct that keeps track of each users bet
    BetBank[] private betBanks;
    
    //bet Struct
    struct BetBank {
        bytes32 bet;
        address owner;
    }
 
    //gets the user balance, requires that the user be the msg.sender, should make it a bit harder to get users balance
    function userBalance() public view returns(uint) {
        return userBank[msg.sender];
    }
    
    //setting up internal bank struct, should prevent prying eyes from seeing other users banks
    mapping (address => uint) public userBank;

    //main deposit function
    function depositBank() public defcon4 payable {
        if(userBank[msg.sender] == 0) {//if the user doesn't have funds
            userBank[msg.sender] = msg.value;//make balance = the funds
        } else {
            userBank[msg.sender] = (userBank[msg.sender]).add(msg.value);//if user already has funds, add to what exists
        }
        bookKeeper = bookKeeper.add(msg.value);//bookkeeper to prevent catastrophic exploits from going too far
        Deposit(msg.sender, msg.value);//broadcast the deposit event
    }
    
    //widthdraw what is in users bank
    function withdrawBank(uint amount) public defcon2 returns(bool) {
        require(userBank[msg.sender] >= amount);//require that the user has enough to withdraw
        bookKeeper = bookKeeper.sub(amount);//update the bookkeeper
        userBank[msg.sender] = userBank[msg.sender].sub(amount);//reduce users account balance
        Withdraw(msg.sender, amount);//broadcast Withdraw event
        (msg.sender).transfer(amount);//transfer the amount to user
        return true;
    }
    
    //create a bet
    function startBet(uint _bet) public defcon3 returns(uint betId) {
        require(userBank[msg.sender] >= _bet);//require user has enough to create the bet
        require(_bet > 0);
        userBank[msg.sender] = (userBank[msg.sender]).sub(_bet);//reduce users bank by the bet amount
        uint convertedAddr = uint(msg.sender);
        uint combinedBet = convertedAddr.add(_bet)*7;
        BetBank memory betBank = BetBank({//birth the bet token
            bet: bytes32(combinedBet),//_bet,
            owner: msg.sender
        });
        //push new bet and get betId
        betId = betBanks.push(betBank).sub(1);//push the bet token and get the Id
    }
   
    //internal function to delete the bet token
    function _endBetListing(uint betId) private returns(bool){
        delete betBanks[betId];//delete that token
    }
    
    //bet a users token against another users token
    function betAgainstUser(uint _betId1, uint _betId2) public defcon3 returns(bool){
        require(betBanks[_betId1].bet != emptyBet && betBanks[_betId2].bet != emptyBet);//require that both tokens are active and hold funds
        require(betBanks[_betId1].owner == msg.sender || betBanks[_betId2].owner == msg.sender); //require that the user submitting is the owner of one of the tokens
        require(betBanks[_betId1].owner != betBanks[_betId2].owner);//prevent a user from betting 2 tokens he owns, prevent possible exploits
        require(_betId1 != _betId2);//require that user doesn't bet token against itself
    
        //unhash the bets to calculate winner
        uint bet1ConvertedAddr = uint(betBanks[_betId1].owner);
        uint bet1 = (uint(betBanks[_betId1].bet)/1254).sub(bet1ConvertedAddr);
        uint bet2ConvertedAddr = uint(betBanks[_betId2].owner);
        uint bet2 = (uint(betBanks[_betId2].bet)/1254).sub(bet2ConvertedAddr);  
        
        uint take = (bet1).add(bet2);//calculate the total rewards for winning
        uint fee = (take.mul(houseFee)).div(100);//calculate the fee
        houseCommission = houseCommission.add(fee);//add fee to commission
        if(bet1 != bet2) {//if no tie
            if(bet1 > bet2) {//if betId1 wins
                _payoutWinner(_betId1, _betId2, take, fee);//payout betId1
            } else {
                _payoutWinner(_betId2, _betId1, take, fee);//payout betId2
            }
        } else {//if its a tie
            if(_random() == 0) {//choose a random winner
                _payoutWinner(_betId1, _betId2, take, fee);//payout betId1
            } else {
                _payoutWinner(_betId2, _betId1, take, fee);//payout betId2
            }
        }
        return true;
    }

    //internal function to pay out the winner
    function _payoutWinner(uint winner, uint loser, uint take, uint fee) private returns(bool) {
        BigBankBet(block.number, betBanks[winner].owner, betBanks[loser].owner, winner, loser, take.sub(fee));//broadcast the BigBankBet event
        address winnerAddr = betBanks[winner].owner;//save the winner address
        _endBetListing(winner);//end the token
        _endBetListing(loser);//end the token
        userBank[winnerAddr] = (userBank[winnerAddr]).add(take.sub(fee));//pay out the winner
        return true;
    }
    
    //set the fee
    function setHouseFee(uint newFee)public onlyOwner returns(bool) {
        require(msg.sender == owner);//redundant require owner
        houseFee = newFee;//set the house fee
        return true;
    }
    
    //withdraw the commission
    function withdrawCommission()public onlyOwner returns(bool) {
        require(msg.sender == owner);//again redundant owner check because who trusts modifiers
        bookKeeper = bookKeeper.sub(houseCommission);//update ;the bookKeeper
        uint holding = houseCommission;//get the commission balance
        houseCommission = 0;//empty the balance
        owner.transfer(holding);//transfer to owner
        return true;
    }
    
    //random function for tiebreaker
    function _random() private view returns (uint8) {
        return uint8(uint256(keccak256(block.timestamp, block.difficulty))%2);
    }
    
    //get amount of active bet tokens
    function _totalActiveBets() private view returns(uint total) {
        total = 0;
        for(uint i=0; i<betBanks.length; i++) {//loop through bets 
            if(betBanks[i].bet != emptyBet && betBanks[i].owner != msg.sender) {//if there is a bet and the owner is not the msg.sender
                total++;//increase quantity
            }
        }
    }
    
    //get list of active bet tokens
    function listActiveBets() public view returns(uint[]) {
        uint256 total = _totalActiveBets();
        if (total == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](total);
            uint rc = 0;
            for (uint idx=0; idx < betBanks.length; idx++) {//loop through bets
                if(betBanks[idx].bet != emptyBet && betBanks[idx].owner != msg.sender) {//if there is a bet and the owner is not the msg.sender
                    result[rc] = idx;//add token to list
                    rc++;
                }
            }
        }
        return result;
    }
    
    //total open bets of user
    function _totalUsersBets() private view returns(uint total) {
        total = 0;
        for(uint i=0; i<betBanks.length; i++) {//loop through bets
            if(betBanks[i].owner == msg.sender && betBanks[i].bet != emptyBet) {//if the bet is over 0 and the owner is msg.sender
                total++;//increase quantity
            }
        }
    }
    
    //get list of active bet tokens
    function listUsersBets() public view returns(uint[]) {
        uint256 total = _totalUsersBets();
        if (total == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](total);
            uint rc = 0;
            for (uint idx=0; idx < betBanks.length; idx++) {//loop through bets
                if(betBanks[idx].owner == msg.sender && betBanks[idx].bet != emptyBet) {//if the bet is over 0 and owner is msg.sender
                    result[rc] = idx;//add to list
                    rc++;
                }
            }
        }
        return result;
    }
    
}