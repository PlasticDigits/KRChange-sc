// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {AmmRouter} from "./amm/AmmRouter02.sol";

contract KRChangeRouter is AmmRouter {
    constructor(address _WETH, address _factory) AmmRouter(_factory, _WETH) {}
}
