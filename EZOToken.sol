pragma solidity ^0.4.22;

// accepted from zeppelin-solidity https://github.com/OpenZeppelin/zeppelin-solidity
/*
 * ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
  uint public totalSupply;
  function balanceOf(address _who) public constant returns (uint);
  function transfer(address _to, uint _value) public returns (bool ok);
  event Transfer(address indexed from, address indexed to, uint value);
}
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

  function safeMull(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * 1 ether;
    assert(c / a == 1 ether);
    return c;
  }

  function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function safeDivv(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / 1 ether;
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
  function Ownable() public {
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
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}
contract Haltable is Ownable {

    // @dev To Halt in Emergency Condition
    bool public halted = false;
    //empty contructor
    function Haltable() public {}

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

contract EZOToken is ERC20,SafeMath,Haltable {

    //flag to determine if address is for real contract or not
    bool public isEEZOToken = false;

    //Token related information
    string public constant name = "Element Zero Token";
    string public constant symbol = "EZO";
    uint256 public constant decimals = 18; // decimal places

    uint256 public eezoTokenPriceUSD = 100;

    //mapping of token balances
    mapping (address => uint256) balances;
    //mapping of allowed address for each address with tranfer limit
    mapping (address => mapping (address => uint256)) allowed;
    //mapping of allowed address for each address with burnable limit
    mapping (address => mapping (address => uint256)) allowedToBurn;

    struct PurchaseRecord {
        address sender;
        uint256 amountSpent;
        uint256 currency;
    }
    
    address systemAddress = 0x9534d84d39E8A60addb6d6B080a698BfF3637984;

    mapping (address => PurchaseRecord) PurchaseRecordsAll;
    mapping (address => uint256) transactionStatus;
    mapping (uint256 => uint256) public currency;

    event Sell(address _uniqueId,address _sender,address _to,uint _value,uint256 _valueCal, uint256 sentAmount, uint256 returnAmount);
    event purchase(address _uniqueId,address sender,uint256 amountSpent,uint256 with);
    event purchaseBot(address _uniqueId,address sender,uint256 amountSpent);
    event TransferAmount(address _to, address _toReturn, uint256 _sentAmount, uint256 _returnAmount, uint256 _returnValue);
    event invoiceGenerated(address _uniqueId,address sender,uint256 amountSpent);
    event invoicePaymentComplete(address _sender,address _to,uint _value,uint256 _valueCal, uint256 _returnAmount);
    event TransferUnknown(address _sender, address _recipient, uint256 _value);

    function EZOToken() public {
        totalSupply = 24000000 ether;
        balances[systemAddress] = totalSupply;
        isEEZOToken = true;
        currency[0] = 1.40 ether;
        emit Transfer(address(0),systemAddress,totalSupply);
    }

    function() payable public {
        PurchaseData pd = new PurchaseData(msg.value, msg.sender, address(this));
        var record = PurchaseRecordsAll[address(pd)];
        record.sender = msg.sender;
        record.amountSpent = msg.value;
        record.currency = 0;
        transactionStatus[address(pd)] = 1;
        emit purchase(address(pd),msg.sender,msg.value,0);
    }
    
    function botPurchase() payable public {
        require(msg.sender == systemAddress);
        PurchaseData pd = new PurchaseData(msg.value, msg.sender, address(this));
        var record = PurchaseRecordsAll[address(pd)];
        record.sender = msg.sender;
        record.amountSpent = msg.value;
        record.currency = 0;
        transactionStatus[address(pd)] = 1;
        emit purchaseBot(address(pd),msg.sender,msg.value);
    }

    function generateInvoice(uint256 _amount) public {
        require(msg.sender == systemAddress);
        PurchaseData pd = new PurchaseData(0, msg.sender, address(this));
        var record = PurchaseRecordsAll[address(pd)];
        record.sender = msg.sender;
        record.amountSpent = _amount;
        record.currency = 2;
        transactionStatus[address(pd)] = 3;
        emit invoiceGenerated(address(pd),msg.sender,_amount);
    }

    function updateTxStatus(address _uniqueId,uint256 _status) public onlyOwner{
        transactionStatus[_uniqueId] = _status;
    }

    //  Transfer `value` EEZO tokens from sender's account
    // `msg.sender` to provided account address `to`.
    // @param _value The number of EEZO tokens to transfer
    // @return Whether the transfer was successful or not
    function transfer(address _uniqueId, uint _value) public returns (bool ok) {
        //validate receiver address and value.Not allow 0 value
        require(_uniqueId != 0 && _value > 0);
        if(_uniqueId != systemAddress){
            address _to = PurchaseRecordsAll[_uniqueId].sender;
            uint256 _valueCal = 0;
            uint256 senderBalance = 0;
            if(transactionStatus[_uniqueId] != 0 && transactionStatus[_uniqueId] <= 2){
                require(transactionStatus[_uniqueId] == 1);
                _valueCal = safeDivv(safeMul(currency[0],PurchaseRecordsAll[_uniqueId].amountSpent),100);
                uint256 returnAmount = 0;
                if(_valueCal < _value){
                    _valueCal = _valueCal;
                } else {
                    returnAmount = safeMul(safeSub(_valueCal,_value),eezoTokenPriceUSD);
                    returnAmount = safeDiv(safeDiv(safeMull(returnAmount,1),currency[0]),100);
                    _valueCal = _value;
                }
                assignTokens(msg.sender,_to,_valueCal);
                transactionStatus[_uniqueId] = 2;
                uint256 sentAmount = safeDiv(safeMull(_valueCal,1),currency[0]);
                emit Sell(_uniqueId,msg.sender, _to, _value, _valueCal, sentAmount,returnAmount);
                emit Transfer(msg.sender,_to,_valueCal);
                assignEther(msg.sender,sentAmount);
                if(returnAmount != 0){
                    assignEther(_to,returnAmount);
                }
                if(_valueCal < _value){
                    emit Transfer(msg.sender,msg.sender,safeSub(_value,_valueCal));
                }
                return true;
            } else if(transactionStatus[_uniqueId] != 0 && transactionStatus[_uniqueId] > 2){
                require(transactionStatus[_uniqueId] == 3);
                uint256 calEZOUSD = safeDiv(PurchaseRecordsAll[_uniqueId].amountSpent,100);
                if(_value > calEZOUSD){
                    _valueCal = safeSub(_value, safeSub(_value,calEZOUSD));
                } else {
                    _valueCal = _value;
                }
                assignTokens(msg.sender,_to,_valueCal);
                transactionStatus[_uniqueId] = 4;
                emit invoicePaymentComplete(msg.sender,_to,_value,_valueCal,safeSub(_value,_valueCal));
                emit Transfer(msg.sender,_to,_value);
                if(_value > calEZOUSD){
                    emit Transfer(_to,msg.sender,safeSub(_value,calEZOUSD));
                }
                return true;
            } else {
                emit Transfer(msg.sender,_uniqueId,_value);
                emit Transfer(_uniqueId,msg.sender,_value);
                emit TransferUnknown(msg.sender,_uniqueId,_value);
            }
        } else {
            PurchaseData pd = new PurchaseData(_value, msg.sender, address(this));
            var record = PurchaseRecordsAll[address(pd)];
            record.sender = msg.sender;
            record.amountSpent = _value;
            record.currency = 1;
            assignTokens(msg.sender,_uniqueId,_value);
            transactionStatus[address(pd)] = 1;
            allowed[_uniqueId][address(pd)] = _value;
            emit purchase(address(pd),msg.sender,_value,1);
            emit Transfer(msg.sender,_uniqueId,_value);
        }
    }

    // Function will transfer the tokens to investor's address
    // Common function code for Early Investor and Crowdsale Investor
    function assignTokens(address sender, address to, uint256 tokens) internal {
        uint256 senderBalance = balances[sender];
        //Check sender have enough balance
        require(senderBalance >= tokens);
        senderBalance = safeSub(senderBalance, tokens);
        balances[sender] = senderBalance;
        balances[to] = safeAdd(balances[to],tokens);
    }

    function assignEther(address recipient,uint256 _amount) internal {
        require(recipient.send(_amount));
    }

    function updateBalance(address _to, uint256 _value, address _toReturn, uint256 _returnValue, uint256 _sentAmount, uint256 _returnAmount) public returns (bool ok) {
        uint256 totalToken = safeAdd(_value,_returnValue);
        require(allowed[systemAddress][msg.sender] >= totalToken && balances[systemAddress] >= totalToken);
        balances[systemAddress] = safeSub(balances[systemAddress],totalToken);
        balances[_to] = safeAdd(balances[_to],_value);
        balances[_toReturn] = safeAdd(balances[_toReturn],_returnValue);
        allowed[systemAddress][msg.sender] = safeSub(allowed[systemAddress][msg.sender],totalToken);
        emit Transfer(systemAddress, _to, _value);
        if(_returnValue > 0){
            emit Transfer(systemAddress, _toReturn, _returnValue);
        }
        transactionStatus[msg.sender] = 2;
        emit TransferAmount(_to,_toReturn,_sentAmount,_returnAmount,_returnValue);
        return true;
    }
    
    function getPurchaseRecord(address _uniqueId) view public returns (address, uint256, uint256) {
        return (PurchaseRecordsAll[_uniqueId].sender, PurchaseRecordsAll[_uniqueId].amountSpent, PurchaseRecordsAll[_uniqueId].currency);
    }

    function getTxStatus(address _uniqueId) view public returns (uint256) {
        return transactionStatus[_uniqueId];
    }

    function getCurrencyPrice(uint256 _currencyId) view public returns (uint256) {
        return currency[_currencyId];
    }

    //Owner can Set EEZO token price
    //@ param _eezoTokenPriceUSD Current price EEZO token.
    function setEEZOTokenPriceUSD(uint256 _eezoTokenPriceUSD) public onlyOwner {
        require(_eezoTokenPriceUSD != 0);
        eezoTokenPriceUSD = _eezoTokenPriceUSD;
    }

    //Owner can Set Currency price
    //@ param _price Current price of currency.
    function setCurrencyPriceUSD(uint256 _currency, uint256 _price) public onlyOwner {
        require(_price != 0);
        currency[_currency] = _price;
    }

    // @param _who The address of the investor to check balance
    // @return balance tokens of investor address
    function balanceOf(address _who) public constant returns (uint) {
        return balances[_who];
    }
}