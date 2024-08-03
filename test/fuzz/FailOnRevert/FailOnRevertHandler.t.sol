// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

// handler is going to narrow down the way we call function
contract FailOnRevertHandler is Test {
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    address weth;
    address wbtc;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    address[] public depsitedUsers;
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;
        address[] memory tokenAddresses = engine.getCollateralTokens();
        weth = tokenAddresses[0];
        wbtc = tokenAddresses[1];
        ethUsdPriceFeed = MockV3Aggregator(
            engine.getCollateralTokenPriceFeed(weth)
        );
        btcUsdPriceFeed = MockV3Aggregator(
            engine.getCollateralTokenPriceFeed(wbtc)
        );
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
        uint userAddressSeed,
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        if (depsitedUsers.length == 0) return;
        address sender = depsitedUsers[userAddressSeed % depsitedUsers.length];
        address tokenAddress = _getCollaterolFromSeed(collateralSeed);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine
            .getAccountInformation(sender);

        //200% overcollateralize
        if (collateralValueInUsd < totalDscMinted * 2) return;
        // the max total collateral can be redeemed in USD without breaking the health factor
        uint256 maxCollateralToRedeemInUsd = collateralValueInUsd -
            totalDscMinted *
            2;
        //the balance of current token
        uint256 balanceOfCollateral = engine.getCollateralBalanceOfUser(
            sender,
            tokenAddress
        );

        uint256 balanceOfCollateralInUsd = engine.getUsdValue(
            tokenAddress,
            balanceOfCollateral
        );
        //the max value can be redeemed in this tx should be:
        //1.less than the value that keep the health threshold.
        //2.less than the balacen of the collateral.
        maxCollateralToRedeemInUsd = maxCollateralToRedeemInUsd <
            balanceOfCollateralInUsd
            ? maxCollateralToRedeemInUsd
            : balanceOfCollateralInUsd;

        uint256 maxCollateralToRedeem = engine.getTokenAmountFromUsd(
            tokenAddress,
            maxCollateralToRedeemInUsd
        );
        if (maxCollateralToRedeem <= 0) return;
        amountCollateral = bound(amountCollateral, 1, maxCollateralToRedeem);
        vm.prank(sender);
        engine.redeemCollatral(tokenAddress, amountCollateral);
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

    function burnDsc(uint256 userAddressSeed, uint256 amountDsc) public {
        if (depsitedUsers.length == 0) return;
        address sender = depsitedUsers[userAddressSeed % depsitedUsers.length];
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(sender));
        if (amountDsc == 0) return;
        vm.prank(sender);
        dsc.approve(address(engine), amountDsc);
        vm.startPrank(address(engine));
        dsc.transferFrom(sender, address(engine), amountDsc);
        dsc.burn(amountDsc);
        vm.stopPrank();
    }

    function liquidate(
        uint256 collateralSeed,
        uint256 userAddressSeed,
        uint256 liquidatorAddressSeed,
        uint256 debtToCover
    ) public {
        if (depsitedUsers.length < 2) return;
        address sender = depsitedUsers[userAddressSeed % depsitedUsers.length];

        address liquidator = depsitedUsers[
            liquidatorAddressSeed % depsitedUsers.length
        ];
        if (liquidator == sender) return;
        uint256 userHealthFactor = engine.getHealthFactor(sender);
        uint256 liquidatorHealthFactor = engine.getHealthFactor(liquidator);

        if (userHealthFactor >= engine.getMinHealthFactor()) return;
        if (liquidatorHealthFactor <= engine.getMinHealthFactor()) return;

        address collateral = _getCollaterolFromSeed(collateralSeed);
        vm.prank(liquidator);
        try
            engine.liquidate(address(collateral), sender, debtToCover)
        {} catch Error(string memory reason) {
            // Handle expected errors
            // Log expected error and continue
            console.log("Unexpected error:", reason);
        }
    }

    /////////////////////////////
    // DecentralizedStableCoin //
    /////////////////////////////
    function transferDsc(
        uint256 fromUserSeed,
        uint256 toUserSeed,
        uint256 amountDsc
    ) public {
        if (depsitedUsers.length < 2) return;
        address fromAddress = depsitedUsers[
            fromUserSeed % depsitedUsers.length
        ];

        address toAddress = depsitedUsers[toUserSeed % depsitedUsers.length];
        if (fromAddress == toAddress) return;
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(fromAddress));
        vm.prank(fromAddress);
        dsc.transfer(toAddress, amountDsc);
    }

    function updateCollateralPrice(uint256 collateralSeed) public {
        address collateral = _getCollaterolFromSeed(collateralSeed);
        MockV3Aggregator priceFeed = MockV3Aggregator(
            engine.getCollateralTokenPriceFeed(address(collateral))
        );
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        uint256 variaction = 100;
        variaction = bound(variaction, 90, 110);

        uint256 intNewPrice = (uint256(answer) * variaction) / 100;

        priceFeed.updateAnswer(int256(intNewPrice));
    }

    function _getCollaterolFromSeed(
        uint256 collateralSeed
    ) private view returns (address) {
        return collateralSeed % 2 == 0 ? weth : wbtc;
    }
}
