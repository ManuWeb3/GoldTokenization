// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract GoldReserveAndPrice {
    AggregatorV3Interface internal immutable s_reserveFeed;
    AggregatorV3Interface internal immutable s_priceFeed;

    /**
     * Network: Ethereum Mainnet
     * Aggregator: CacheGold PoR
     * Address: 0x5586bf404c7a22a4a4077401272ce5945f80189c

     * Aggregator: XAU/USD
     * Address: 0x214ed9da11d2fbe465a6fc601a91e62ebec1a0d6
     */
    constructor() {
        s_reserveFeed = AggregatorV3Interface(
            0x5586bF404C7A22A4a4077401272cE5945f80189C
        );

        s_priceFeed = AggregatorV3Interface(
            0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6
        );
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        // prettier-ignore
        (
            /*uint80 roundID*/,
            int priceGold,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = s_priceFeed.latestRoundData();

        return priceGold;
    }

    /**
     * Returns the latest reserve
*/
    function getLatestReserve() public view returns (int) {
        // prettier-ignore
        (
            /*uint80 roundID*/,
            int reserveGold,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = s_reserveFeed.latestRoundData();

        return reserveGold;
    }
}
