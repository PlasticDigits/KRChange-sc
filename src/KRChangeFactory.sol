// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {AmmFactory} from "./amm/AmmFactory.sol";

contract KRChangeFactory is AmmFactory {
    constructor(address owner) AmmFactory(owner) {}
}
