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