// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run()
        external
        returns (DecentralizedStableCoin, DSCEngine, HelperConfig)
    {
        HelperConfig helperConfig = new HelperConfig();
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        DSCEngine engine;
        DecentralizedStableCoin coin;
        vm.startBroadcast(deployerKey);
        coin = new DecentralizedStableCoin();
        engine = new DSCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(coin)
        );
        coin.transferOwnership(address(engine));
        vm.stopBroadcast();
        return (coin, engine, helperConfig);
    }
}
