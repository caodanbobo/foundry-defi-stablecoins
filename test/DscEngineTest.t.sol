// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig helperConfig;
    address weth;
    address wbtc;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant AMOUT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BAL = 10 ether;

    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );

    event CollateralRedeemed(
        address indexed redeemFrom,
        address indexed redeemTo,
        address indexed token,
        uint256 amount
    );

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, engine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, ) = helperConfig
            .activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BAL);
        ERC20Mock(weth).mint(LIQUIDATOR, STARTING_ERC20_BAL);
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertIfTokenLengthDoseNotMatchPriceLength() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);

        vm.expectRevert(
            DSCEngine
                .DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength
                .selector
        );
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /*//////////////////////////////////////////////////////////////
                              PRICES TEST
    //////////////////////////////////////////////////////////////*/
    function testGetTokenAmountFromUsd() public view {
        // uint256 tokenAmt = engine.getTokenAmountFromUsd(weth, 1000 * 1e18);
        // uint256 expectedValue = 1e18 / 2;

        uint256 tokenAmt = engine.getTokenAmountFromUsd(weth, 1000 ether);
        uint256 expectedValue = 0.5 ether;
        assert(tokenAmt == expectedValue);
    }

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        //1eth = 2000usd
        uint256 expectedUsd = 3e22;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assert(expectedUsd == actualUsd);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSITECOLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__AmountLessThanZero.selector);
        engine.depositeCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertWithUnapprovedToken() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, 1000);
        vm.expectRevert(DSCEngine.DSCEngine__TokenIsNotAllowed.selector);
        engine.depositeCollateral(address(ranToken), 100);
    }

    function testCanDepositeAndSeeTheEvent() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUT_COLLATERAL);

        vm.expectEmit(true, true, true, true);
        emit CollateralDeposited(USER, address(weth), 5);

        engine.depositeCollateral(weth, 5);
        vm.stopPrank();

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine
            .getAccountInformation(USER);
        assert(totalDscMinted == 0);
        assert(collateralValueInUsd == engine.getUsdValue(weth, 5));
    }

    function testDepositeMatchedAccountValue() public {
        ERC20Mock(wbtc).mint(USER, STARTING_ERC20_BAL);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUT_COLLATERAL);
        ERC20Mock(wbtc).approve(address(engine), AMOUT_COLLATERAL);
        engine.depositeCollateral(weth, AMOUT_COLLATERAL);
        uint256 expectCollateralInUsd = AMOUT_COLLATERAL * 2000;
        assert(
            expectCollateralInUsd == engine.getAccountCollateralValueInUsd(USER)
        );
        engine.depositeCollateral(wbtc, AMOUT_COLLATERAL);
        expectCollateralInUsd += AMOUT_COLLATERAL * 20000;
        assert(
            expectCollateralInUsd == engine.getAccountCollateralValueInUsd(USER)
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             MINTDSC TESTS
    //////////////////////////////////////////////////////////////*/
    function testMintRevertLessThanZero() public {
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__AmountLessThanZero.selector);
        engine.mintDsc(0);
    }

    modifier depositeEthToUser() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUT_COLLATERAL);
        engine.depositeCollateral(weth, AMOUT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testMintAfterDeposite() public depositeEthToUser {
        vm.startPrank(USER);
        uint256 totalCollateralInUsd = engine.getAccountCollateralValueInUsd(
            USER
        );
        uint256 maxToMint = totalCollateralInUsd / 2;
        engine.mintDsc(maxToMint);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine
            .getAccountInformation(USER);
        assert(totalDscMinted == maxToMint);
        assert(
            collateralValueInUsd == engine.getUsdValue(weth, AMOUT_COLLATERAL)
        );

        vm.stopPrank();
    }

    function testMintFailWithHealthFactorIsBorken() public depositeEthToUser {
        vm.startPrank(USER);

        uint256 totalCollateralInUsd = engine.getAccountCollateralValueInUsd(
            USER
        );
        uint256 maxToMint = totalCollateralInUsd / 2;
        engine.mintDsc(maxToMint);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                99
            )
        );
        engine.mintDsc(1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               BURN TESTS
    //////////////////////////////////////////////////////////////*/

    modifier depositeAndMint() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUT_COLLATERAL);
        uint256 totalCollateralInUsd = engine.getUsdValue(
            weth,
            AMOUT_COLLATERAL
        );
        console.log(totalCollateralInUsd);
        uint256 maxToMint = totalCollateralInUsd / 2;
        console.log(maxToMint);
        engine.depositeCollateralAndMintDsc(weth, AMOUT_COLLATERAL, maxToMint);
        vm.stopPrank();
        _;
    }

    function testBurnDsc() public depositeAndMint {
        uint256 initialBalance = engine.getDSCMintedByUser(USER);
        uint256 burntAmount = initialBalance / 2;
        vm.startPrank(USER);
        dsc.approve(address(engine), burntAmount);
        engine.burnDsc(burntAmount);
        uint256 endingBalance = engine.getDSCMintedByUser(USER);
        assert(initialBalance - burntAmount == endingBalance);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testRedeemAmountLessThanZero() public {
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__AmountLessThanZero.selector);
        engine.redeemCollatral(weth, 0);
    }

    function testRedeemAllAndEmitEvent() public depositeEthToUser {
        vm.prank(USER);
        vm.expectEmit(true, true, true, true);
        emit CollateralRedeemed(USER, USER, weth, AMOUT_COLLATERAL);
        engine.redeemCollatral(weth, AMOUT_COLLATERAL);
        uint256 wethBalance = ERC20Mock(weth).balanceOf(USER);
        assert(wethBalance == AMOUT_COLLATERAL);
    }

    function testRedeemRevertIfHealthFactorIsBorken() public depositeAndMint {
        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                0
            )
        );
        engine.redeemCollatral(weth, AMOUT_COLLATERAL);
    }

    /*//////////////////////////////////////////////////////////////
                            LIQUIDATE TESTS
    //////////////////////////////////////////////////////////////*/
    function testLiquidateAmountNotMoreThanZero() public {
        vm.prank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngine__AmountLessThanZero.selector);
        engine.liquidate(weth, USER, 0);
    }

    function testLiquidateRevertedWithHealthFactorOk() public depositeAndMint {
        vm.prank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, USER, 100);
    }

    modifier setUpUSERAndLiquidator() {
        if (block.chainid == 11155111) return;
        //1 eth = $2000, mint 1000 dsc, right at MIN_HEALTH_FACTOR
        uint256 mintAmount = 1000 ether;
        //setup USER
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), 1 ether);

        engine.depositeCollateralAndMintDsc(weth, 1 ether, mintAmount);
        vm.stopPrank();

        //setup LIQUIDATOR
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(engine), 2 ether);
        engine.depositeCollateralAndMintDsc(weth, 2 ether, mintAmount);
        vm.stopPrank();

        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(1500e8);
        _;
    }

    function testHealthFactor() public setUpUSERAndLiquidator {
        //1500 * 50 /100= 750
        //750 * 100/ 1000=75
        uint256 expectedFactor = 75;
        assert(engine.healthFactor(USER) == expectedFactor);
    }

    function testLiquidateRevertWithHealthFactorNotImproved()
        public
        setUpUSERAndLiquidator
    {
        uint256 liquidateAmount = 1;
        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(engine), liquidateAmount);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        engine.liquidate(weth, USER, liquidateAmount);
    }
}
