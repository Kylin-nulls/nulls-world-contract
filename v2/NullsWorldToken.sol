//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/INullsWorldToken.sol";

contract NullsWorldToken is ERC20 {

    address Owner ;
    address Oper ;
    uint public BeginTime = 0 ;
    uint public Free1day = 3000000000;


    uint8 Decimals = 6;
    uint256 MaxSupply;

    struct Rank {
        uint score ;
        uint used ; 
    }

    struct Report {
        uint score ;  
        uint total ;    
    }

    address public NullsExcitation;

    mapping( uint => mapping( address => Rank) ) Ranks ;
    mapping( uint => Report ) Reports ;
    mapping( address => uint ) public UserCanWithdraw;
    mapping( address => uint ) public UserLastUpdateDay;

    event IncrDayScore(address player , uint dayIndex, uint incr , uint balance , uint total , uint8 _type, uint8 index);
    event ReceiveToken( address player , uint val );

    modifier onlyOwner() {
        require( msg.sender == Owner , "NullsWorldToken/No role." );
        _ ; 
    }

    modifier onlyOper() {
        require( msg.sender == Oper , "NullsWorldToken/No oper role." );
        _ ;
    }

    modifier onlyNullsExcitation() {
        require( msg.sender == NullsExcitation , "NullsWorldToken/No nulls excitation role.");
        _ ;
    }

    function decimals() public view override returns (uint8) {
        return Decimals;
    }

    modifier updateUserCanWithdraw(address player) {
      uint dayIndex = getDayIndex();
      uint lastDayIndex = UserLastUpdateDay[player];
      if(dayIndex != lastDayIndex) {
          Rank storage oldRank = Ranks[ lastDayIndex ][player] ;
          Report memory oldReport = Reports[ lastDayIndex ] ;
          if (oldRank.score > 0 && oldRank.score > oldRank.used) {
              uint v = oldRank.score - oldRank.used ;
              uint tmpFree1day = Free1day * 1e10 * v;
              oldRank.used = oldRank.used + v ;
              UserCanWithdraw[player] += ( tmpFree1day / oldReport.score ) / 1e10;
          }
          UserLastUpdateDay[player] = dayIndex;
      }
      _;
    }

    constructor(uint256 maxSupply_) ERC20("Nulls.World Token ","NWT") {
        Owner = msg.sender ;
        Oper = msg.sender;
        MaxSupply = maxSupply_;
    }

    function setNullsExcitation(address addr) external onlyOper {
        NullsExcitation = addr;
    }

    function mint( address player , uint total ) external onlyOper {
        _mint( player , total );
    }
    
    function modifierOwner( address owner ) external onlyOwner {
        Owner = owner ;
    }

    function modifierOper( address oper ) external onlyOwner {
        Oper = oper ;
    }

    function getDayIndex() public view returns ( uint idx ) {
        idx = ( block.timestamp - BeginTime ) / ( 1 days ) ;
    }

    function setBeginTime( uint ts ) external onlyOwner {
        BeginTime = ts ;
    }

    function incrDayScore(address player,uint score, uint8 _type, uint8 index) external onlyNullsExcitation updateUserCanWithdraw(player) {
        uint tv = 0 ;
        uint dayIndex = getDayIndex();
        Rank storage rank = Ranks[ dayIndex ][player] ;
        Report storage report = Reports[ dayIndex ] ;

        
        if( rank.score == 0 ) {
            tv = 1 ;
        }
        rank.score = rank.score + score ;
        report.score = report.score + score ;
        report.total = report.total + tv ;

        emit IncrDayScore(player, dayIndex, score , rank.score , report.score,  _type, index);
    }

    function _beforeTokenTransfer(
        address from,
        address,
        uint256 amount
    ) internal override view {
        // mint
        if (from == address(0)) {
            require( (totalSupply() + amount) <= MaxSupply, "NullsWorldToken/Over mint limit");
        }
    }

    function getDayScore(address player, uint dayIndex) public view returns(uint totalScore, uint palyNum, uint playerScore) {
        Report memory report = Reports[dayIndex] ;
        totalScore = report.score;
        palyNum = report.total;
        Rank memory rank = Ranks[ dayIndex ][player] ;
        playerScore = rank.score;
    }

    function receiveToken() external updateUserCanWithdraw(msg.sender) {
        uint amount = UserCanWithdraw[msg.sender];
        require(amount > 0, "NullsWorldToken/The withdrawal amount is 0");
        _mint( msg.sender , amount);
        UserCanWithdraw[msg.sender] = 0;
        emit ReceiveToken( msg.sender, amount );
    }
}
