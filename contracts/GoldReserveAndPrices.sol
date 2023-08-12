// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";    // 8 decimals for all 3 values below

contract GoldReserveAndPrices {
    AggregatorV3Interface internal immutable i_reserveFeed;
    AggregatorV3Interface internal immutable i_priceFeedGold;
    AggregatorV3Interface internal immutable i_priceFeedEth;

    /**
     * Network: Ethereum Mainnet
     * Aggregator: CacheGold PoR
     * Address: 0x5586bf404c7a22a4a4077401272ce5945f80189c

     * Aggregator: XAU/USD
     * Address: 0x214ed9da11d2fbe465a6fc601a91e62ebec1a0d6

     * Aggregator: ETH/USD
     * Address: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
     */
    constructor() {
        i_reserveFeed = AggregatorV3Interface(
            0x5586bF404C7A22A4a4077401272cE5945f80189C
        );

        i_priceFeedGold = AggregatorV3Interface(
            0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6
        );

        i_priceFeedEth = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
    }

    /**
     * Returns the latest price of ETH/USD
     */
    function getLatestPriceEth() public view returns (int) {
        // prettier-ignore
        (
            /*uint80 roundID*/,
            int priceEth,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = i_priceFeedEth.latestRoundData();

        return priceEth;
    }

    /**
     * Returns the latest price of XAU(GOLD)/USD
     */
    function getLatestPriceGold() public view returns (int) {
        // prettier-ignore
        (
            /*uint80 roundID*/,
            int priceGold,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = i_priceFeedGold.latestRoundData();

        return priceGold;
    }

    /**
     * Returns the latest reserve of GOLD with CacheGold
*/
    function getLatestReserve() public view returns (int) {
        // prettier-ignore
        (
            /*uint80 roundID*/,
            int reserveGold,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = i_reserveFeed.latestRoundData();

        return reserveGold;
    }

    function getDecimalsPriceFeedEthUSD() external view returns (uint8) {
        return i_priceFeedEth.decimals();
    }
    // can code same fn. for other 2 as well, likewise the above one.
}
