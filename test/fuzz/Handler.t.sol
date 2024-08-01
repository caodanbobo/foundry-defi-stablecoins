// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

// handler is going to narrow down the way we call function
contract Handler is Test {
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    address weth;
    address wbtc;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    address[] public depsitedUsers;
    MockV3Aggregator public ethUsdPriceFeed;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;
        address[] memory tokenAddresses = engine.getCollateralTokens();
        weth = tokenAddresses[0];
        wbtc = tokenAddresses[1];
        ethUsdPriceFeed = MockV3Aggregator(
            engine.getCollateralTokenPriceFeed(weth)
        );
    }

    function mintDsc(uint userAddressSeed, uint256 amount) public {
        if (depsitedUsers.length == 0) return;
        address sender = depsitedUsers[userAddressSeed % depsitedUsers.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine
            .getAccountInformation(sender);
        int256 maxToMint = (int256(collateralValueInUsd) / 2) -
            int256(totalDscMinted);
        if (maxToMint <= 0) return;
        vm.startPrank(sender);
        amount = bound(amount, 1, uint256(maxToMint));
        engine.mintDsc(amount);
        vm.stopPrank();
    }

    function depositeCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        address tokenAddress = _getCollaterolFromSeed(collateralSeed);
        vm.startPrank(msg.sender);
        ERC20Mock(tokenAddress).mint(msg.sender, amountCollateral);
        ERC20Mock(tokenAddress).approve(address(engine), amountCollateral);
        engine.depositeCollateral(tokenAddress, amountCollateral);
        vm.stopPrank();
        depsitedUsers.push(msg.sender);
    }

    function redeemCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        address tokenAddress = _getCollaterolFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = engine.getCollateralBalanceOfUser(
            msg.sender,
            tokenAddress
        );
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        vm.prank(msg.sender);
        engine.redeemCollatral(tokenAddress, amountCollateral);
    }

    //this will break our invariant test suite, it can cause price surge
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceFeed = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceFeed);
    // }

    function _getCollaterolFromSeed(
        uint256 collateralSeed
    ) private view returns (address) {
        return collateralSeed % 2 == 0 ? weth : wbtc;
    }
}
