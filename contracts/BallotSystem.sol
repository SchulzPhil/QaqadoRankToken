//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function burn(
        address account,
        uint256 amount
    ) external returns (bool);

    function mint(
        address account,
        uint256 amount
    ) external returns (bool);
}


contract Ballot {

    using Strings for uint256;
    IERC20 private Token;

    mapping(uint => mapping(address => uint)) public forMint;
    mapping(uint => mapping(address => uint)) public forBurn;

    mapping(uint => mapping(bool => uint)) public votes;
    mapping(uint => mapping(address => bool)) public wasVoted;

    mapping(uint => address[]) private addressesForMint;
    mapping(uint => address[]) private addressesForBurn;
    mapping(uint => address[]) private votersAddresses;

    mapping(uint => address) public votingInitiator;

    address public owner;
    uint public ballotNumber;

    mapping(uint => uint) public totalVoters;
    mapping(uint => uint) public startTime;
    mapping(uint => uint) public endTime;

    enum State { Created, Voting, Ended }
    State public state;

    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    modifier isFirstVote() {
        require(wasVoted[getBallotNumber()][msg.sender] == false, "You already voted");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not owner");
        _;
    }

    modifier onlyStaff() {
        require(msg.sender == owner || msg.sender == votingInitiator[getBallotNumber()], "You are not owner/staff");
        _;
    }

    constructor(address _token) {
        Token = IERC20(_token);
        state = State.Created;
        owner = msg.sender;
    }

    function assignVotingInitiator(address account) public onlyOwner {
        votingInitiator[getBallotNumber()] = account;
    }


    function getBallotNumber() public view returns (uint) {
        return ballotNumber;
    }

    function startAndSetupBallotMint
    (
        address[] memory _addressForMint, uint[] memory _amountForMint,
        uint _totalTimeForVoting
    )
        public
        inState(State.Created)
        onlyStaff
    {
        require(1 days <= _totalTimeForVoting && _totalTimeForVoting <= 30 days, "Ballot time should be in 1 month");

        require(_addressForMint.length == _amountForMint.length, "number of addresses and amount shoud be equal");
        for (uint i; i < _addressForMint.length; i++) {
            forMint[getBallotNumber()][ _addressForMint[i] ] = _amountForMint[i];
        }

        addressesForMint[getBallotNumber()] = _addressForMint;
        votersAddresses[getBallotNumber()].push(msg.sender);

        totalVoters[getBallotNumber()]++;
        votes[getBallotNumber()][true] += Token.balanceOf(msg.sender);
        wasVoted[getBallotNumber()][msg.sender] = true;

        startTime[getBallotNumber()] = block.timestamp;
        endTime[getBallotNumber()] = _totalTimeForVoting + startTime[getBallotNumber()];
        state = State.Voting;
    }

    function startAndSetupBallotBurn
    (
        address[] memory _addressForBurn, uint[] memory _amountForBurn,
        uint _totalTimeForVoting
    )
        public
        inState(State.Created)
        onlyStaff
    {
        require(1 days <= _totalTimeForVoting && _totalTimeForVoting <= 30 days, "Ballot time should be in 1 month");

        require(_addressForBurn.length == _amountForBurn.length, "number of addresses and amount shoud be equal");
        for (uint i; i < _addressForBurn.length; i++) {

            if (Token.balanceOf(_addressForBurn[i]) < _amountForBurn[i]) {

                string memory addr = Strings.toHexString(uint160(_addressForBurn[i]), 20);
                revert(string.concat(
                    "account ", addr, " has ", Token.balanceOf(_addressForBurn[i]).toString(), " tokens ",
                    "but you want burn ", _amountForBurn[i].toString(), " tokens"));
            } else {
                forBurn[getBallotNumber()][ _addressForBurn[i] ] = _amountForBurn[i];
            }
        }

        addressesForBurn[getBallotNumber()] = _addressForBurn;
        votersAddresses[getBallotNumber()].push(msg.sender);

        totalVoters[getBallotNumber()]++;
        votes[getBallotNumber()][true] += Token.balanceOf(msg.sender);
        wasVoted[getBallotNumber()][msg.sender] = true;

        startTime[getBallotNumber()] = block.timestamp;
        endTime[getBallotNumber()] = _totalTimeForVoting + startTime[getBallotNumber()];
        state = State.Voting;
    }

    function makeVote(bool choice) public inState(State.Voting) isFirstVote {
        require(block.timestamp < endTime[getBallotNumber()], "Ballot was finished");
        wasVoted[getBallotNumber()][msg.sender] = true;

        totalVoters[getBallotNumber()]++;
        votes[getBallotNumber()][choice] += Token.balanceOf(msg.sender);
        votersAddresses[getBallotNumber()].push(msg.sender);
    }

    function endVote() public inState(State.Voting) onlyOwner returns (bool) {
        require(block.timestamp >= endTime[getBallotNumber()], "Ballot still going");
        state = State.Ended;

        if(votes[getBallotNumber()][true] > votes[getBallotNumber()][false]) {
            if(addressesForMint[getBallotNumber()].length > 0){
                for(uint i; i < addressesForMint[getBallotNumber()].length; i++) {
                    Token.mint(addressesForMint[getBallotNumber()][i], forMint[getBallotNumber()][addressesForMint[getBallotNumber()][i]]);
                }
            }
            if(addressesForBurn[getBallotNumber()].length > 0){
                for(uint i; i < addressesForBurn[getBallotNumber()].length; i++) {
                    Token.burn(addressesForBurn[getBallotNumber()][i], forBurn[getBallotNumber()][addressesForBurn[getBallotNumber()][i]]);
                }
            }
        } else {
            return false;
        }

        ballotNumber++;
        state = State.Created;
        return true;
    }
}
