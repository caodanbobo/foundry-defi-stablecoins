// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

// handler is going to narrow down the way we call function
contract ContinueOnRevertHandler is Test {
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    address weth;
    address wbtc;
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;

    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

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
        //vm.prank(msg.sender);
        engine.redeemCollatral(tokenAddress, amountCollateral);
    }

    function burnDsc(uint256 amountDsc) public {
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        dsc.burn(amountDsc);
    }

    function mintDsc(uint256 amount) public {
        amount = bound(amount, 1, amount);
        engine.mintDsc(amount);
    }

    function liquidate(
        uint256 collateralSeed,
        address userToBeLiquidated,
        uint256 debtToCover
    ) public {
        address collateral = _getCollaterolFromSeed(collateralSeed);
        engine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
    }

    /////////////////////////////
    // DecentralizedStableCoin //
    /////////////////////////////
    function transferDsc(uint256 amountDsc, address to) public {
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        vm.prank(msg.sender);
        dsc.transfer(to, amountDsc);
    }

    //random price change will break our invariant test suite, it can cause price surge
    //the following code set the price variation within 10%.

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

    function callSummary() external view {
        console.log(
            "Weth total deposited",
            ERC20Mock(weth).balanceOf(address(engine))
        );
        console.log(
            "Wbtc total deposited",
            ERC20Mock(wbtc).balanceOf(address(engine))
        );
        console.log("Total supply of DSC", dsc.totalSupply());
    }
}
