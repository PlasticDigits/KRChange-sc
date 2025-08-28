// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {KRChangeFactory} from "../src/KRChangeFactory.sol";
import {KRChangeRouter} from "../src/KRChangeRouter.sol";
import {AmmZapV1} from "../src/amm/AmmZapV1.sol";

contract DeployDex is Script {
    KRChangeFactory public krChangeFactory;
    KRChangeRouter public krChangeRouter;
    AmmZapV1 public ammZapV1;

    //0x654A3287c317D4Fc6e8482FeF523Dc4572b563AA //97 (KASPLEX TESTNET)
    address WETH = address(0x654A3287c317D4Fc6e8482FeF523Dc4572b563AA);
    address OWNER = address(0x37406d829c86a8e0144301633fb2B78feDc0Ba55);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        krChangeFactory = new KRChangeFactory(OWNER);
        krChangeRouter = new KRChangeRouter(WETH, address(krChangeFactory));
        ammZapV1 = new AmmZapV1(WETH, address(krChangeRouter), OWNER, 50);

        vm.stopBroadcast();
    }
}
