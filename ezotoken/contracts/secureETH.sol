pragma solidity 0.5.9;

//@title IERC20 : interface for an ERC20 Token
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value)
        external
        returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
    function mint(address account, uint256 amount) external returns (bool);
    function burn(address account, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
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

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

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
    modifier runIfHalted {
        require(halted);
        _;
    }

    // @dev called by only owner in case of any emergecy situation
    function halt() public onlyOwner stopIfHalted {
        halted = true;
    }
    // @dev called by only owner to stop the emergency situation
    function unHalt() public onlyOwner runIfHalted {
        halted = false;
    }
}

contract SecureETH is IERC20, Haltable, SafeMath {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    constructor() public {
        _name = "secureETH";
        _symbol = "SETH";
        _decimals = 18;
    }

    address[] public allowedForBurningTokens;
    modifier isAllowed() {
        bool flag = false;
        for (uint256 i = 0; i < allowedForBurningTokens.length; i++) {
            if (msg.sender == allowedForBurningTokens[i]) {
                flag = true;
                break;
            }

        }
        require(flag, "Not allowed");
        _;
    }

    function allowAddressToBurnTokens(address _addressToBeAllowed)
        public
        onlyOwner
    {
        allowedForBurningTokens.push(_addressToBeAllowed);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        return false;
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        returns (bool)
    {
        return false;
    }

    function allowance(address owner, address spender)
        public
        view
        returns (uint256)
    {
        return 0;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        return false;
    }

    function burn(address account, uint256 amount)
        public
        isAllowed
        returns (bool)
    {
        _burn(account, amount);
        return true;
    }

    function mint(address account, uint256 amount)
        public
        isAllowed
        returns (bool)
    {
        _mint(account, amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = safeAdd(_totalSupply, amount);
        _balances[account] = safeAdd(_balances[account], amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = safeSub(_balances[account], amount);
        _totalSupply = safeSub(_totalSupply, amount);
        emit Transfer(account, address(0), amount);
    }
}
