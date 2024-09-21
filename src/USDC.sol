//SPDX-License-Identifier: MIT
import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

pragma solidity ^0.8.25;

contract USDC is ERC20{

    constructor() ERC20("USDC","USDC"){
        _mint(msg.sender,1000000000*10**18);
    }
}