pragma solidity 0.5.9;

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

contract CurrencyPrices is Haltable {
    
    mapping (address => uint256) public currencyPrices;
    mapping (address => uint256) public currencyDecimal;
    
    //Owner can Set Currency decimal
    //@ param _currency Currency.
    //@ param _decimal Decimal of currency.
    function setCurrencyDecimal(address[] memory _currency, uint256[] memory _decimal) public onlyOwner {
        require(_currency.length == _decimal.length);
        for(uint8 i = 0; i < _currency.length; i++){
            require(_decimal[i] != 0);
            currencyDecimal[_currency[i]] = _decimal[i];   
        }
    }
    
    //Owner can Set Currency price
    //@ param _currency Currency.
    //@ param _price Current price of currency.
    function setCurrencyPriceUSD(address[] memory _currency, uint256[] memory _price) public onlyOwner {
        require(_currency.length == _price.length);
        for(uint8 i = 0; i < _currency.length; i++){
            require(_price[i] != 0);
            currencyPrices[_currency[i]] = _price[i];   
        }
    }
    
}