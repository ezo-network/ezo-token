pragma solidity ^0.4.22;

import './SafeMath.sol';

contract PurchaseData is SafeMath{
    
    uint256 public value;
    address public sender;
    EZOToken eezo;
    
    function PurchaseData(uint256 _value,address _sender,address _eezoToken) public{
        value = _value;
        sender = _sender;
        eezo = EZOToken(_eezoToken);
    }

    function() payable public{
        require(eezo.getTxStatus(address(this)) == 1);
        //validate receiver address and value.Not allow 0 value
        require(sender != 0 && value > 0);
        uint256 eezoPrice = eezo.getCurrencyPrice(0);
        uint256 _valueCal = safeDivv(safeMul(eezoPrice,msg.value),100);
        uint256 returnAmount = 0;
        if(_valueCal < value){
            eezo.updateBalance(msg.sender,_valueCal,sender,safeSub(value,_valueCal),msg.value,0);
            _valueCal = msg.value;
        } else {
            _valueCal = safeDiv(safeMull(value,100),eezoPrice);
            returnAmount = safeSub(msg.value,_valueCal);
            eezo.updateBalance(msg.sender,value,sender,0,_valueCal,returnAmount);
        }
        sender.send(_valueCal);
        if(returnAmount > 0){
            msg.sender.send(returnAmount);
        }
    }
}