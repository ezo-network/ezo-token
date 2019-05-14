pragma solidity ^0.4.22;

import './SafeMath.sol';

contract PurchaseData is SafeMath{
    
    uint256 public value;
    address public sender;
    EZOToken ezo;
    
    function PurchaseData(uint256 _value,address _sender,address _ezoToken) public{
        value = _value;
        sender = _sender;
        ezo = EZOToken(_ezoToken);
    }
}