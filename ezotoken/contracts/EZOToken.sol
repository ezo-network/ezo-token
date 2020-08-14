pragma solidity 0.5.9;

// accepted from zeppelin-solidity https://github.com/OpenZeppelin/zeppelin-solidity
/*
 * ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
  uint public totalSupply;
  function balanceOf(address _who) public view returns (uint);
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
    function approve(address _spender, uint256 _value) public returns (bool success);
}

contract CurrencyPrices {
    mapping (address => uint256) public currencyPrices;
    mapping (address => uint256) public currencyDecimal;
}

contract PurchaseData is SafeMath{
    
    uint256 public value;
    address public sender;
    
    constructor(uint256 _value,address _sender) public{
        value = _value;
        sender = _sender;
    }
}

interface IEscrow {
 function canceledP2P(address user, uint256 value) external returns(bool);
}

contract EZOToken is ERC20,SafeMath,Haltable {

    //flag to determine if address is for real contract or not
    bool public isEZOToken = false;

    //Token related information
    string public constant name = "Element Zero Token";
    string public constant symbol = "EZO";
    uint256 public constant decimals = 18; // decimal places

    uint256 public ezoTokenPriceUSD = 100;

    //mapping of token balances
    mapping (address => uint256) balances;

    struct PurchaseRecord {
        address payable sender;
        address beneficiary;
        uint256 amountSpent;
        address currency;
    }
    
    address systemAddress = 0x2a3a91f51CA13a464500c2200E6D025a53d39Bbb;
    address public currencyPricesContract = 0x0c815Cd72A8B1CbAF4C0ef6b4394C42D2BdC3caA;

    mapping (address => PurchaseRecord) PurchaseRecordsAll;
    mapping (address => uint256) transactionStatus;
    mapping (address => bool) public allowedAddresses;

    event Sell(address _uniqueId,address _sender,address _to,uint _value,uint256 _valueCal, uint256 sentAmount, uint256 returnAmount, address currency);
    event sendETHForEZO(address _uniqueId,address sender,uint256 amountSpent);
    event TransferUnknown(address _sender, address _recipient, uint256 _value);
    event redemForEZOToken(address _from, address _to, uint256 _tokens, string _retCurrency);
    event sendTokenForEZO(address _uniqueId, address sender, uint256 amountSpent);
    event Mint(address _to, uint256 _tokens);
    event Burn(address _from, uint256 _tokens);
    event systemAssign(address token,address to, uint256 amount);
    event orderCanceled(uint256,address,address);

    constructor() public {
        totalSupply = 2400 ether;
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0),msg.sender,totalSupply);
        isEZOToken = true;
    }
    
    function addAllowedAddress(address _allowAddr, bool _permission) public onlyOwner {
        require(_allowAddr != address(0));
        allowedAddresses[_allowAddr] = _permission;
    }
    
    //Owner can Set CurrencyPrices contract address
    //@ param _currencyPricesContract Address of EZOToken contract.
    function setCurrencyPricesContractAddress(address _currencyPricesContract) public onlyOwner {
        require(_currencyPricesContract != address(0));
        currencyPricesContract = _currencyPricesContract;
    }

    function() payable external {
        PurchaseData pd = new PurchaseData(msg.value, msg.sender);
        PurchaseRecord storage record = PurchaseRecordsAll[address(pd)];
        record.beneficiary = msg.sender;
        record.sender = msg.sender;
        record.amountSpent = msg.value;
        record.currency = address(0);
        transactionStatus[address(pd)] = 1;
        emit sendETHForEZO(address(pd),msg.sender,msg.value);
    }

    function sendToken(address token, uint amount) public {
        require(token != address(0) && CurrencyPrices(currencyPricesContract).currencyPrices(token) > 0);
        require(Token(token).transferFrom(msg.sender, address(this), amount));
        PurchaseData pd = new PurchaseData(amount, msg.sender);
        PurchaseRecord storage record = PurchaseRecordsAll[address(pd)];
        record.beneficiary = msg.sender;
        record.sender = msg.sender;
        record.amountSpent = amount;
        record.currency = token;
        transactionStatus[address(pd)] = 1;
        emit sendTokenForEZO(address(pd),msg.sender,amount);
    }
    
    function sendTokenFormEscrow(address token, uint amount, address payable sender) public {
      require(token != address(0) && CurrencyPrices(currencyPricesContract).currencyPrices(token) > 0);
      require(Token(token).transferFrom(msg.sender, address(this), amount));
      PurchaseData pd = new PurchaseData(amount, sender);
      PurchaseRecord storage record = PurchaseRecordsAll[address(pd)];
      record.beneficiary = msg.sender;
      record.sender = sender;
      record.amountSpent = amount;
      record.currency = token;
      transactionStatus[address(pd)] = 1;
      emit sendTokenForEZO(address(pd),sender,amount);
    }
    
    function escrowTransfer (address _uniqueId, uint returnAmount) internal {
        PurchaseRecord storage pr = PurchaseRecordsAll[_uniqueId];
        Token(pr.currency).approve(pr.beneficiary, returnAmount);
        IEscrow(pr.beneficiary).canceledP2P(pr.sender, returnAmount);
    }
    
    function cancelOrder(address _uniqueId) public {
        require(msg.sender == PurchaseRecordsAll[_uniqueId].sender);
        require(transactionStatus[_uniqueId] == 1);
        transactionStatus[_uniqueId] = 2;
        if (msg.sender == PurchaseRecordsAll[_uniqueId].beneficiary) {
            generalFundAssign(PurchaseRecordsAll[_uniqueId].currency,PurchaseRecordsAll[_uniqueId].sender,PurchaseRecordsAll[_uniqueId].amountSpent);
        }
        else {
            escrowTransfer(_uniqueId, PurchaseRecordsAll[_uniqueId].amountSpent);
        }
    }
    
    function generalFundAssign(address _currencySent,address payable _recipient, uint256 _amount) internal {
        if(_currencySent == address(this)) {
            mint(_recipient,_amount);
            emit orderCanceled(_amount,_recipient,_currencySent);
        } else if(_currencySent == address(0)) {
            require(address(this).balance >= _amount);
            assignEther(_recipient,_amount);
            emit orderCanceled(_amount,_recipient,address(0));
        } else {
            require(Token(_currencySent).balanceOf(address(this)) >= _amount);
            Token(_currencySent).transfer(_recipient,_amount);
            emit orderCanceled(_amount,_recipient,_currencySent);
        }
    }

    function updateTxStatus(address _uniqueId,uint256 _status) public onlyOwner{
        transactionStatus[_uniqueId] = _status;
    }

    //  Transfer `value` EZO tokens from sender's account
    // `msg.sender` to provided account address `to`.
    // @param _value The number of EZO tokens to transfer
    // @return Whether the transfer was successful or not
    function transfer(address _uniqueId, uint _value) stopIfHalted public returns (bool ok) {
        //validate receiver address and value.Not allow 0 value
        require(_uniqueId != address(0) && _uniqueId != address(this) && _value > 0);
        if(_uniqueId != systemAddress){
            address payable _to = PurchaseRecordsAll[_uniqueId].sender;
            uint256 _valueCal = 0;
            address curAddress = PurchaseRecordsAll[_uniqueId].currency;
            if(transactionStatus[_uniqueId] != 0 && transactionStatus[_uniqueId] <= 2){
                require(transactionStatus[_uniqueId] == 1);
                _valueCal = safeDiv(safeMul(safeDiv(safeMul(PurchaseRecordsAll[_uniqueId].amountSpent,10**CurrencyPrices(currencyPricesContract).currencyDecimal(address(this))), 10**CurrencyPrices(currencyPricesContract).currencyDecimal(curAddress)), CurrencyPrices(currencyPricesContract).currencyPrices(curAddress)),CurrencyPrices(currencyPricesContract).currencyPrices(address(this)));
                uint256 returnAmount = 0;
                if(_valueCal > _value) {
                    returnAmount = safeDiv(safeMul(safeDiv(safeMul(safeSub(_valueCal,_value),10**CurrencyPrices(currencyPricesContract).currencyDecimal(curAddress)), 10**18),100),CurrencyPrices(currencyPricesContract).currencyPrices(curAddress));
                    _valueCal = _value;
                }
                assignTokens(msg.sender,_to,_valueCal);
                transactionStatus[_uniqueId] = 2;
                uint256 sentAmount = safeDiv(safeMul(safeDiv(safeMul(_valueCal,10**CurrencyPrices(currencyPricesContract).currencyDecimal(curAddress)), 10**18),100),CurrencyPrices(currencyPricesContract).currencyPrices(curAddress));
                emit Sell(_uniqueId,msg.sender, _to, _value, _valueCal, sentAmount, returnAmount, curAddress);
                emit Transfer(msg.sender,_to,_valueCal);
                if(curAddress == address(0)){
                    assignEther(msg.sender,sentAmount);
                    if(returnAmount != 0){
                        assignEther(_to,returnAmount);
                    }
                } else {
                    Token(curAddress).transfer(msg.sender,sentAmount);
                    if(returnAmount != 0){
                        if (_to == PurchaseRecordsAll[_uniqueId].beneficiary) {
                            Token(curAddress).transfer(_to,returnAmount);
                        } else {
                            escrowTransfer(_uniqueId, returnAmount);
                        }
                    }
                }
                if(_valueCal < _value){
                    emit Transfer(msg.sender,msg.sender,safeSub(_value,_valueCal));
                }
                return true;
            } 
            else {
                emit Transfer(msg.sender,_uniqueId,_value);
                emit Transfer(_uniqueId,msg.sender,_value);
                emit TransferUnknown(msg.sender,_uniqueId,_value);
            }
        } else {
            assignTokens(msg.sender,_uniqueId,_value);
            emit Transfer(msg.sender,_uniqueId,_value);
        }
    }
    
    // Function will create new tokens and assign to investor's address
    function mint(address to, uint256 tokens) stopIfHalted public returns (bool) {
        require(allowedAddresses[msg.sender]);
        totalSupply = safeAdd(totalSupply, tokens);
        balances[to] = safeAdd(balances[to], tokens);
        emit Mint(to, tokens);
        emit Transfer(address(0), to, tokens);
        return true;
    }

    // Function will burn tokens from investor's address
    function burn(address from, uint256 tokens) stopIfHalted public returns (bool) {
        require(allowedAddresses[msg.sender]);
        require(balances[from] >= tokens);
        totalSupply = safeSub(totalSupply, tokens);
        balances[from] = safeSub(balances[from], tokens);
        emit Burn(from, tokens);
        emit Transfer(from, address(0), tokens);
        return true;
    }
    
    // Function will transfer the tokens to investor's address
    function assignTokens(address sender, address to, uint256 tokens) internal {
        uint256 senderBalance = balances[sender];
        //Check sender have enough balance
        require(senderBalance >= tokens);
        senderBalance = safeSub(senderBalance, tokens);
        balances[sender] = senderBalance;
        balances[to] = safeAdd(balances[to],tokens);
    }

    function assignEther(address payable recipient,uint256 _amount) internal {
        require(recipient.send(_amount));
    }
    
    function getPurchaseRecord(address _uniqueId) view public returns (address, uint256, address) {
        return (PurchaseRecordsAll[_uniqueId].sender, PurchaseRecordsAll[_uniqueId].amountSpent, PurchaseRecordsAll[_uniqueId].currency);
    }

    function getTxStatus(address _uniqueId) view public returns (uint256) {
        return transactionStatus[_uniqueId];
    }

    function getCurrencyPrice(address _currencyId) view public returns (uint256) {
        return CurrencyPrices(currencyPricesContract).currencyPrices(_currencyId);
    }

    //Owner can Set EZO token price
    //@ param _ezoTokenPriceUSD Current price EZO token.
    function setEZOTokenPriceUSD(uint256 _ezoTokenPriceUSD) public onlyOwner {
        require(_ezoTokenPriceUSD != 0);
        ezoTokenPriceUSD = _ezoTokenPriceUSD;
    }

    // @param _who The address of the investor to check balance
    // @return balance tokens of investor address
    function balanceOf(address _who) public view returns (uint) {
        return balances[_who];
    }
}