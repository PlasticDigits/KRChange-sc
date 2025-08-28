// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.19;

import {MockERC20 as BaseMockERC20} from "lib/forge-std/src/mocks/MockERC20.sol";

contract MintableMockERC20 is BaseMockERC20 {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function init(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external {
        initialize(name_, symbol_, decimals_);
    }
}
