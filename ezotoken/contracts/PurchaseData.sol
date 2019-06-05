pragma solidity ^0.5.8;

import './SafeMath.sol';

contract PurchaseData is SafeMath{
    
    uint256 public value;
    address public sender;
    
    constructor(uint256 _value,address _sender) public{
        value = _value;
        sender = _sender;
    }
}