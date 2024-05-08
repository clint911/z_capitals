/* Contract that asks chainlink for price of BTC
 *The Current start it simply asking for price so it can be used for start of computation, later, it will be remodelled to ask for more but lets not get ahead of ourselves here*/
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceFetcherContract {
    uint256 public currWBTCPriceFromOracle;
 AggregatorV3Interface internal priceFeed;
 /*
 The ETH/USD Price Feed reference contract on the Kovan Testnet is deployed at the address 0x9326BFA02ADD2366b30bacB125260Af641031331.
 */
//variable to hold the address of our pair on a specific network/testnet
address public pairAddressOnSpecificTestnet;
priceFeed = AggregatorV3Interface(pairAddressOnSpecificTestnet);

//NOTE: We have ints here, taka caution and ensure proper checks and conversion
function getLatestPrice() public view returns (int256) {
  (
  uint80 roundID,///Decimals of the asset
  int price,
  uint startedAt,
  uint timeStamp,
  uint80 answeredInRound,
  )
  =
  priceFeed.latestRoundData();
  return price;
}

