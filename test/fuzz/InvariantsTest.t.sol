// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//what are our invaraints?
//1. The total supple of dsc should be less than the total value of collateral
//2. Getter view functions should never revert <- evergreen invairant
import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig helperConfig;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, engine, helperConfig) = deployer.run();
        (, , weth, wbtc, ) = helperConfig.activeNetworkConfig();
        handler = new Handler(engine, dsc);
        targetContract(address(handler));
    }

    /**
     *@notice invariant functions are not required to be defined as view, but they commonly are. This is because the primary purpose of invariant functions is to check the state of the contract without modifying it.
     */
    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = ERC20Mock(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = ERC20Mock(wbtc).balanceOf(address(engine));
        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);
        console.log("weth value", wethValue);
        console.log("wbtc value", wbtcValue);
        console.log("total supply", totalSupply);
        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_getterShouldNotRevert() public view {
        // all the getters should be listed here
        // <forge inspect DSCEngine methods>
        engine.getPrecision();
    }
}
