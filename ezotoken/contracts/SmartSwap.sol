pragma solidity 0.5.9;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
contract SafeMath {
  function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}
contract Haltable is Ownable {

    // @dev To Halt in Emergency Condition
    bool public halted = false;
    //empty contructor
    constructor() public {}

    // @dev Use this as function modifier that should not execute if contract state Halted
    modifier stopIfHalted {
      require(!halted);
      _;
    }

    // @dev Use this as function modifier that should execute only if contract state Halted
    modifier runIfHalted{
      require(halted);
      _;
    }

    // @dev called by only owner in case of any emergecy situation
    function halt() onlyOwner stopIfHalted public {
        halted = true;
    }
    // @dev called by only owner to stop the emergency situation
    function unHalt() onlyOwner runIfHalted public {
        halted = false;
    }
}

contract Token {
    function transfer(address _to, uint _value) public returns (bool ok) {}
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {}
    function balanceOf(address _who) public view returns (uint);
    function mint(address to, uint256 tokens) public returns (bool ok) {}
    function burn(address from, uint256 tokens) public returns (bool ok) {}
}

contract PurchaseData {
    
    uint256 public value;
    address public sender;
    
    constructor(uint256 _value,address _sender) public{
        value = _value;
        sender = _sender;
    }
}

contract EZOToken {
    function mint(address to, uint256 tokens) public returns (bool ok) {}
    function burn(address from, uint256 tokens) public returns (bool ok) {}
}

contract CurrencyPrices {
    mapping (address => uint256) public currencyPrices;
    mapping (address => uint256) public currencyDecimal;
}

contract SmartSwap is SafeMath,Haltable {
    
    struct PurchaseRecord{
        address payable sender;
        uint256 amountSent;
        uint256 remainingAmount;
        address currencySent;
        address currencyWant;
        bool status;
    }
    
    struct Order{
        PurchaseRecord[] orderDetails;
    }
    
    bool public inExecution = false;
    address public ezoTokenAddress = 0xef55BfAc4228981E850936AAf042951F7b146e41;
    address public currencyPricesContract = 0x5E72914535f202659083Db3a02C984188Fa26e9f;
    address public secureETHContractAddress = 0x8c1eD7e19abAa9f23c476dA86Dc1577F1Ef401f5;
    
    mapping (address => mapping (address => Order)) orderAll;
    mapping (address => uint256) public tokenBalancesForEZO;
    
    event orderAdded(uint256,uint256,address,address,address);
    event orderCompleted(uint256,address,address);
    event redemForEZOToken(address, uint256, address, address);
    
    constructor() public{
    }
    
    //Owner can Set EZOToken contract address
    //@ param _ezoTokenAddress Address of EZOToken contract.
    function setEZOTokenAddress(address _ezoTokenAddress) public onlyOwner {
        require(_ezoTokenAddress != address(0));
        ezoTokenAddress = _ezoTokenAddress;
    }
    
    //Owner can Set CurrencyPrices contract address
    //@ param _currencyPricesContract Address of EZOToken contract.
    function setCurrencyPricesContractAddress(address _currencyPricesContract) public onlyOwner {
        require(_currencyPricesContract != address(0));
        currencyPricesContract = _currencyPricesContract;
    }
    
    //Owner can Set secureETH contract address
    //@ param _secureETHContractAddress Address of secureETH contract.
    function setSecureETHContractAddress(address _secureETHContractAddress) public onlyOwner {
        require(_secureETHContractAddress != address(0));
        secureETHContractAddress = _secureETHContractAddress;
    }
    
    function getPendingOrders(address currencySent,address currencyWant,uint256 index) public view returns(address,uint256,uint256,address,address,bool){
        return (orderAll[currencySent][currencyWant].orderDetails[index].sender,orderAll[currencySent][currencyWant].orderDetails[index].amountSent,orderAll[currencySent][currencyWant].orderDetails[index].remainingAmount,orderAll[currencySent][currencyWant].orderDetails[index].currencySent,orderAll[currencySent][currencyWant].orderDetails[index].currencyWant,orderAll[currencySent][currencyWant].orderDetails[index].status);    
    }
    
    function sendEther(address _currencyWant) payable external {
        addOrder(msg.value,msg.sender,address(0),_currencyWant);
    }

    function sendToken(address token, uint amount, address _currencyWant) public {
        require(token != address(0));
        require(Token(token).transferFrom(msg.sender, address(this), amount));
        addOrder(amount,msg.sender,token,_currencyWant);
    }
    
    function redemForEZO(uint256 _amount, address _currencyWant) public {
        EZOToken(ezoTokenAddress).burn(msg.sender,_amount);
        addOrder(_amount,msg.sender,ezoTokenAddress,_currencyWant);
        emit redemForEZOToken(msg.sender,_amount,ezoTokenAddress,_currencyWant);
    }
    
    function cancelOrder(address _currencySent,address _currencyWant,uint256 _index) public {
        require(msg.sender == orderAll[_currencySent][_currencyWant].orderDetails[_index].sender);
        require(!orderAll[_currencySent][_currencyWant].orderDetails[_index].status);
        orderAll[_currencySent][_currencyWant].orderDetails[_index].status = true;
        generalFundAssign(_currencySent,orderAll[_currencySent][_currencyWant].orderDetails[_index].sender,orderAll[_currencySent][_currencyWant].orderDetails[_index].remainingAmount);
    }
    
    function addOrder(uint256 _sentAmount, address payable _sender, address _currencySent,address _currencyWant) internal {
        if(_currencyWant == ezoTokenAddress){
            orderAll[_currencySent][_currencyWant].orderDetails.push(PurchaseRecord(_sender,_sentAmount,0,_currencySent,_currencyWant,true));
            tokenBalancesForEZO[_currencySent] = safeAdd(tokenBalancesForEZO[_currencySent],_sentAmount);
            generalFundAssign(ezoTokenAddress,_sender,safeDiv(safeMul(safeDiv(safeMul(_sentAmount,10**CurrencyPrices(currencyPricesContract).currencyDecimal(ezoTokenAddress)), 10**CurrencyPrices(currencyPricesContract).currencyDecimal(_currencySent)),CurrencyPrices(currencyPricesContract).currencyPrices(_currencySent)),CurrencyPrices(currencyPricesContract).currencyPrices(ezoTokenAddress)));
        } else if(_currencySent == ezoTokenAddress){
            if(generalFundAssignEZO(_currencyWant,_sender,safeDiv(safeMul(safeDiv(safeMul(_sentAmount,10**CurrencyPrices(currencyPricesContract).currencyDecimal(_currencyWant)), 10**CurrencyPrices(currencyPricesContract).currencyDecimal(ezoTokenAddress)),CurrencyPrices(currencyPricesContract).currencyPrices(ezoTokenAddress)),CurrencyPrices(currencyPricesContract).currencyPrices(_currencyWant)))){
                orderAll[_currencySent][_currencyWant].orderDetails.push(PurchaseRecord(_sender,_sentAmount,0,_currencySent,_currencyWant,true));   
            } else {
                orderAll[_currencySent][_currencyWant].orderDetails.push(PurchaseRecord(_sender,_sentAmount,_sentAmount,_currencySent,_currencyWant,false));
            }
        } else {
            orderAll[_currencySent][_currencyWant].orderDetails.push(PurchaseRecord(_sender,_sentAmount,_sentAmount,_currencySent,_currencyWant,false));    
        }
        emit orderAdded((orderAll[_currencySent][_currencyWant].orderDetails.length-1),_sentAmount,_sender,_currencySent,_currencyWant);
    }
    
    function checkStability(address _currencySentNewOrder,address _currencyWantNewOrder,uint256 _indexNew,uint256 _indexOld) public returns(bool){
        require(!inExecution);
        require(CurrencyPrices(currencyPricesContract).currencyPrices(_currencySentNewOrder) > 0 && CurrencyPrices(currencyPricesContract).currencyPrices(_currencyWantNewOrder) > 0);
        inExecution = true;
        address currencySentNewOrder = orderAll[_currencySentNewOrder][_currencyWantNewOrder].orderDetails[_indexNew].currencySent;            
        address currencyWantNewOrder = orderAll[_currencySentNewOrder][_currencyWantNewOrder].orderDetails[_indexNew].currencyWant;        
        uint256 remainingAmountNewOrder = orderAll[_currencySentNewOrder][_currencyWantNewOrder].orderDetails[_indexNew].remainingAmount;
            
            if(_indexNew < orderAll[currencySentNewOrder][currencyWantNewOrder].orderDetails.length && _indexOld < orderAll[currencyWantNewOrder][currencySentNewOrder].orderDetails.length){
                uint256 remainingAmountPendingOrder = orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].remainingAmount;
                uint256 returnCurrencyAmount = getReturnAmount(remainingAmountPendingOrder, _currencySentNewOrder, _currencyWantNewOrder, _indexOld);
                
                if(!orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].status && !orderAll[_currencySentNewOrder][_currencyWantNewOrder].orderDetails[_indexNew].status){
                    if(returnCurrencyAmount < remainingAmountNewOrder){
                        orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].status = true;
                        orderAll[_currencySentNewOrder][_currencyWantNewOrder].orderDetails[_indexNew].remainingAmount = safeSub(remainingAmountNewOrder,returnCurrencyAmount);
                        generalFundAssign(currencyWantNewOrder,orderAll[_currencySentNewOrder][_currencyWantNewOrder].orderDetails[_indexNew].sender,remainingAmountPendingOrder);
                        generalFundAssign(orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].currencyWant,orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].sender,remainingAmountNewOrder - (remainingAmountNewOrder-returnCurrencyAmount));
                        inExecution = false;
                    } else if(returnCurrencyAmount > remainingAmountNewOrder){
                        orderAll[_currencySentNewOrder][_currencyWantNewOrder].orderDetails[_indexNew].status = true;
                        orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].remainingAmount = getCalValue(returnCurrencyAmount,remainingAmountNewOrder,_currencySentNewOrder,_currencyWantNewOrder);
                        generalFundAssign(currencyWantNewOrder,orderAll[_currencySentNewOrder][_currencyWantNewOrder].orderDetails[_indexNew].sender,remainingAmountPendingOrder - (getCalValue(returnCurrencyAmount,remainingAmountNewOrder,_currencySentNewOrder,_currencyWantNewOrder)));
                        generalFundAssign(orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].currencyWant,orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].sender,remainingAmountNewOrder);
                        inExecution = false;
                    } else if(returnCurrencyAmount == remainingAmountNewOrder){
                        orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].status = true;
                        orderAll[_currencySentNewOrder][_currencyWantNewOrder].orderDetails[_indexNew].status = true;
                        orderAll[_currencySentNewOrder][_currencyWantNewOrder].orderDetails[_indexNew].remainingAmount = 0;                        
                        orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].remainingAmount = 0;
                        generalFundAssign(currencyWantNewOrder,orderAll[_currencySentNewOrder][_currencyWantNewOrder].orderDetails[_indexNew].sender,remainingAmountPendingOrder);
                        generalFundAssign(orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].currencyWant,orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].sender,remainingAmountNewOrder);
                        inExecution = false;
                    }
                } else {
                    revert();
                }
            } else {
                revert();
            }
    }
    
    function getReturnAmount(uint256 _remainingAmountPendingOrder, address _currencySentNewOrder,address _currencyWantNewOrder,uint256 _indexOld) internal view returns(uint256){
        return safeDiv(safeMul(safeDiv(safeMul(_remainingAmountPendingOrder, 10**CurrencyPrices(currencyPricesContract).currencyDecimal(orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].currencyWant)), 10**CurrencyPrices(currencyPricesContract).currencyDecimal(orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].currencySent)), CurrencyPrices(currencyPricesContract).currencyPrices(orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].currencySent)), CurrencyPrices(currencyPricesContract).currencyPrices(orderAll[_currencyWantNewOrder][_currencySentNewOrder].orderDetails[_indexOld].currencyWant));
    }
    
    function getCalValue(uint256 returnCurrencyAmount, uint256 remainingAmountNewOrder,address _currencySent,address _currencyWant) internal view returns(uint256){
        return ((returnCurrencyAmount-remainingAmountNewOrder) * (safeDiv(safeMul(CurrencyPrices(currencyPricesContract).currencyPrices(_currencySent),1 ether),CurrencyPrices(currencyPricesContract).currencyPrices(_currencyWant))))/ 1 ether;
    }
    
    function generalFundAssign(address _currencyWantNewOrder,address payable _recipient, uint256 _amount) internal {
        if(_currencyWantNewOrder == ezoTokenAddress) {
            EZOToken(ezoTokenAddress).mint(_recipient,_amount);
            emit orderCompleted(_amount,_recipient,_currencyWantNewOrder);
        } else if(_currencyWantNewOrder == address(0)) {
            require(address(this).balance >= _amount);
            assignEther(_recipient,_amount);
            emit orderCompleted(_amount,_recipient,address(0));
        } else {
            require(Token(_currencyWantNewOrder).balanceOf(address(this)) >= _amount);
            systemAssignToken(_currencyWantNewOrder,_recipient,_amount);   
            emit orderCompleted(_amount,_recipient,_currencyWantNewOrder);
        }
    }
    
    function generalFundAssignEZO(address _currencyWantNewOrder,address payable _recipient, uint256 _amount) internal returns (bool) {
        require(tokenBalancesForEZO[_currencyWantNewOrder] >= _amount);
        if(_currencyWantNewOrder == address(0)) {
            if(address(this).balance >= _amount){
                tokenBalancesForEZO[_currencyWantNewOrder] = safeSub(tokenBalancesForEZO[_currencyWantNewOrder],_amount);
                assignEther(_recipient,_amount);
                emit orderCompleted(_amount,_recipient,address(0));   
                return true;
            } else {
                return false;
            }
        } else {
            if(Token(_currencyWantNewOrder).balanceOf(address(this)) >= _amount){
                tokenBalancesForEZO[_currencyWantNewOrder] = safeSub(tokenBalancesForEZO[_currencyWantNewOrder],_amount);
                systemAssignToken(_currencyWantNewOrder,_recipient,_amount);   
                emit orderCompleted(_amount,_recipient,_currencyWantNewOrder);   
                return true;
            } else {
                return false;
            }
        }
    }
    
    function assignEther(address payable recipient,uint256 _amount) internal {
        require(recipient.send(_amount));
    }

    function systemAssignToken(address token,address _to,uint256 _amount) internal {
        Token(token).transfer(_to,_amount);
    }
    
    //@notice function to withdraw ether equivalent of the tokens msg.sender has

    function _sendEther() payable public {
        require(msg.value > 0);
        // emit EtherSent(msg.sender,msg.value);
        //get the price of ether from currencyPrices contract
        //calculate tokensToBeTransfered (it assumes that the deployed ERC20 contract has decimals = 18)
        tokenBalancesForEZO[address(0)] = safeAdd(tokenBalancesForEZO[address(0)],msg.value);
        Token(secureETHContractAddress).mint(msg.sender , safeMul(CurrencyPrices(currencyPricesContract).currencyPrices(address(0)),msg.value));
    }
    
    function _withdrawEther() public{
        uint256 tokensToWithdraw = Token(secureETHContractAddress).balanceOf(msg.sender);
        //@dev burn tokens equivalent to amount
        Token(secureETHContractAddress).burn(msg.sender,tokensToWithdraw);
        if(address(this).balance >= safeAdd(tokenBalancesForEZO[address(0)], safeDiv(tokensToWithdraw,CurrencyPrices(currencyPricesContract).currencyPrices(address(0))))){
            Token(secureETHContractAddress).burn(msg.sender,tokensToWithdraw);
            tokenBalancesForEZO[address(0)] = safeSub(tokenBalancesForEZO[address(0)],safeDiv(tokensToWithdraw,CurrencyPrices(currencyPricesContract).currencyPrices(address(0))));
            assignEther(msg.sender,safeDiv(tokensToWithdraw,CurrencyPrices(currencyPricesContract).currencyPrices(address(0))));   
        } else if(address(this).balance >= tokenBalancesForEZO[address(0)]) {
            Token(secureETHContractAddress).burn(msg.sender,safeMul(safeSub(address(this).balance,tokenBalancesForEZO[address(0)]),CurrencyPrices(currencyPricesContract).currencyPrices(address(0))));
            uint256 etherToSend = safeSub(address(this).balance,tokenBalancesForEZO[address(0)]);
            tokenBalancesForEZO[address(0)] = safeSub(tokenBalancesForEZO[address(0)],safeSub(address(this).balance,tokenBalancesForEZO[address(0)]));
            assignEther(msg.sender,etherToSend);
        } else {
            revert();
        }
        //emit EtherWithdrawed(msg.sender,etherToBetransfered);
    }

    function withdraw(uint256 amount) public onlyOwner returns(bool) {
        assignEther(msg.sender,amount);
       // emit EtherWithdrawed(msg.sender,amount);
        return true;
    }
    
    //@notice fallaback function to allow owner to send ether to the contract (e.g.- in case of price drop)
    function () external payable onlyOwner{
         //emit EtherSent(msg.sender,msg.value);
    }
    
}