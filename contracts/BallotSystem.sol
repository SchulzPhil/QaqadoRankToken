//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract QaqadoRankBallot {

    using Strings for uint256;
    IERC20 private Token;

    mapping(address => uint) public forMint;
    mapping(address => uint) public forBurn;
    mapping(bool => uint) public votes;

    uint public totalVoters;

    enum State { Created, Voting, Ended}
    State public state;

    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    constructor(address _token) {
        Token = IERC20(_token);
        state = State.Created;
    }


    function startAndSetupBallot
    (
        address[] memory _addressForMint, uint[] memory _amountForMint,
        address[] memory _addressForBurn, uint[] memory _amountForBurn
    )
        public
        inState(State.Created)
    {
        for (uint i; i < _addressForMint.length; i++) {
            require(_addressForMint.length == _amountForMint.length, "error");
            forMint[ _addressForMint[i] ] = _amountForMint[i];
        }

        for (uint i; i < _addressForBurn.length; i++) {
            require(_addressForBurn.length == _amountForBurn.length, "error");

            if(Token.balanceOf(_addressForBurn[i]) < _amountForBurn[i] ) {

                string memory addr = Strings.toHexString(uint160(_addressForBurn[i]), 20);
                revert(string.concat(
                    "account ", addr, " has ", Token.balanceOf(_addressForBurn[i]).toString(), " tokens ",
                    "but you want burn ", _amountForBurn[i].toString(), " tokens"));

            } else {
                forBurn[ _addressForBurn[i] ] = _amountForBurn[i];
            }
        }

        totalVoters++;
        votes[true] +=  Token.balanceOf(msg.sender);
    }

    function makeVote(bool choice) public inState(State.Voting) {
        totalVoters++;
        votes[choice] += Token.balanceOf(msg.sender);
    }



}
//args:

    //1 - address[] memory _forMint
    //2 - address[] memory _forMint
    //3 - uint[] memory _amountForMint
    //4 - uint[] memory _amountForBurn

//MINT
// ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2"]
// [22, 55]

//BURN
// ["0xdD870fA1b7C4700F2BD7f44238821C26f7392148", "0x583031D1113aD414F02576BD6afaBfb302140225"]
// [100, 500]
