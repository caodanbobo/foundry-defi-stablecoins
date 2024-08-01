// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//what are our invaraints?
//1. The total supple of dsc should be less than the total value of collateral
//2. Getter view functions should never revert <- evergreen invairant
// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
// import {DSCEngine} from "src/DSCEngine.sol";
// import {DeployDSC} from "script/DeployDSC.s.sol";
// import {HelperConfig} from "script/HelperConfig.s.sol";
// import {ERC20Mock} from "../mocks/ERC20Mock.sol";

// contract OpenInvariantTest is StdInvariant, Test {
//     DeployDSC deployer;
//     DecentralizedStableCoin dsc;
//     DSCEngine engine;
//     HelperConfig helperConfig;
//     address weth;
//     address wbtc;

//     function setUp() external {
//         deployer = new DeployDSC();
//         (dsc, engine, helperConfig) = deployer.run();
//         (, , weth, wbtc, ) = helperConfig.activeNetworkConfig();
//         targetContract(address(engine));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 totalWethDeposited = ERC20Mock(weth).balanceOf(address(engine));
//         uint256 totalWbtcDeposited = ERC20Mock(wbtc).balanceOf(address(engine));
//         uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
//         uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);
//         assert(wethValue + wbtcValue >= totalSupply);
//     }
// }
