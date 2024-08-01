// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title OracleLib
 * @author caodanbobo
 * @notice this library is used to check the Chainlink for stale data.
 * if a price is stale, the function will revert, and render the DESEngine unusable, this is by design.
 * we want the DSCEngine to freeze if prices become stale.
 *
 * WARNING: So if the Chainlink network explodes and you have a lot money locked in the protocal...
 *
 *
 */
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StalePrice();
    uint256 private constant TIMEOUT = 3 hours; // 3* 60 * 60

    function stalePriceCheckLastestRoundData(
        AggregatorV3Interface priceFeed
    ) public view returns (uint80, int256, uint256, uint256, uint80) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        uint256 secondSince = block.timestamp - updatedAt;
        if (secondSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
