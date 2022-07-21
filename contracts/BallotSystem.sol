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

    mapping(address => uint) public forMint;
    mapping(address => uint) public forBurn;

    mapping(bool => uint) public votes;
    mapping(address => bool) public wasVoted;

    address[] private addressesForMint;
    address[] private addressesForBurn;
    address[] private votersAddresses;


    address public votingInitiator;
    address public owner;

    uint public totalVoters;
    uint public startTime;
    uint public endTime;

    enum State { Created, Voting, Ended}
    State public state;

    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    modifier _wasVoted() {
        require(wasVoted[msg.sender] == false, "You already voted");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not owner");
        _;
    }

    modifier onlyStaff() {
        require(msg.sender == owner || msg.sender == votingInitiator, "You are not owner/staff");
        _;
    }

    constructor(address _token) {
        Token = IERC20(_token);
        state = State.Created;
        owner = msg.sender;
    }

    function assignVotingInitiator(address account) public onlyOwner {
        votingInitiator = account;
    }

    function startAndSetupBallot
    (
        address[] memory _addressForMint, uint[] memory _amountForMint,
        address[] memory _addressForBurn, uint[] memory _amountForBurn,
        uint _totalTimeForVoting
    )
        public
        inState(State.Created)
        onlyStaff
    {
        require(1 days <=_totalTimeForVoting && _totalTimeForVoting <= 30 days, "error");

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
        addressesForMint = _addressForMint;
        addressesForBurn = _addressForBurn;
        votersAddresses.push(msg.sender);

        totalVoters++;
        votes[true] +=  Token.balanceOf(msg.sender);
        wasVoted[msg.sender] = true;

        startTime = block.timestamp;
        endTime = _totalTimeForVoting + startTime;
        state = State.Voting;
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
        require(1 days <=_totalTimeForVoting && _totalTimeForVoting <= 30 days, "error");

        for (uint i; i < _addressForMint.length; i++) {
            require(_addressForMint.length == _amountForMint.length, "error");
            forMint[ _addressForMint[i] ] = _amountForMint[i];
        }

        addressesForMint = _addressForMint;
        votersAddresses.push(msg.sender);

        totalVoters++;
        votes[true] += Token.balanceOf(msg.sender);
        wasVoted[msg.sender] = true;

        startTime = block.timestamp;
        endTime = _totalTimeForVoting + startTime;
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
        require(1 days <=_totalTimeForVoting && _totalTimeForVoting <= 30 days, "error");

        for (uint i; i < _addressForBurn.length; i++) {
            require(_addressForBurn.length == _amountForBurn.length, "error");

            if (Token.balanceOf(_addressForBurn[i]) < _amountForBurn[i]) {

                string memory addr = Strings.toHexString(uint160(_addressForBurn[i]), 20);
                revert(string.concat(
                    "account ", addr, " has ", Token.balanceOf(_addressForBurn[i]).toString(), " tokens ",
                    "but you want burn ", _amountForBurn[i].toString(), " tokens"));
            } else {
                forBurn[ _addressForBurn[i] ] = _amountForBurn[i];
            }
        }

        addressesForBurn = _addressForBurn;
        votersAddresses.push(msg.sender);

        totalVoters++;
        votes[true] += Token.balanceOf(msg.sender);
        wasVoted[msg.sender] = true;

        startTime = block.timestamp;
        endTime = _totalTimeForVoting + startTime;
        state = State.Voting;
    }

    function makeVote(bool choice) public inState(State.Voting) _wasVoted {
        require(block.timestamp < endTime, "Ballot was finished");
        wasVoted[msg.sender] = true;

        totalVoters++;
        votes[choice] += Token.balanceOf(msg.sender);
        votersAddresses.push(msg.sender);
    }

    function endVote() public inState(State.Voting) onlyOwner returns (bool) {
        require(block.timestamp >= endTime, "Ballot still going");
        state = State.Ended;

        if(votes[true] > votes[false]) {
            if(addressesForMint.length > 0){
                for(uint i; i < addressesForMint.length; i++) {
                    Token.mint(addressesForMint[i], forMint[addressesForMint[i]]);
                }
            }
            if(addressesForBurn.length > 0){
                for(uint i; i < addressesForBurn.length; i++) {
                    Token.burn(addressesForBurn[i], forBurn[addressesForBurn[i]]);
                }
            }
        } else {
            return false;
        }
        return true;
    }

    function resetBallot() public onlyOwner inState(State.Ended) {

        for(uint i; i < addressesForMint.length; i++) {
            delete forMint[addressesForMint[i]];
        }

        for(uint i; i < addressesForBurn.length; i++) {
            delete forBurn[addressesForBurn[i]];
        }

        for(uint i; i < votersAddresses.length; i++) {
            delete wasVoted[votersAddresses[i]];
        }

        delete votes[true];
        delete votes[false];
        delete addressesForBurn;
        delete addressesForMint;
        delete votersAddresses;
        delete votingInitiator;
        delete totalVoters;
        delete startTime;
        delete endTime;

        state = State.Created;
    }
}
