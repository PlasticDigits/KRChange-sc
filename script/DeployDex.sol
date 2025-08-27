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

    address WETH = address(0x0);
    //0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c //56 (BNB MAINNET)
    //0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd //97 (BNB TESTNET)
    address OWNER = address(0x0);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        krChangeFactory = new KRChangeFactory(OWNER);
        krChangeRouter = new KRChangeRouter(WETH, address(krChangeFactory));
        ammZapV1 = new AmmZapV1(WETH, address(krChangeRouter), OWNER, 50);

        vm.stopBroadcast();
    }
}
