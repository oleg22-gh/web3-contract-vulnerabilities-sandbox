// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.26;

contract NaiveCasino {

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function betAndResolve() payable external {
        uint rand = block.timestamp % 2;
        require(address(this).balance > msg.value * 2, "The house has not enough money");
        if (rand == 0) {
            (bool success,) = msg.sender.call{value: msg.value * 2}("");
            require(success, "transaction has failed");
        }
    }

    function withdraw() public {
        require(owner == msg.sender, "you are not owner");
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "transaction has failed");
    }

    receive() payable external {}

}