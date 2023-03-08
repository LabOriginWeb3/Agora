// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ERC20} from './ERC20.sol';

contract MockCurrency is ERC20('Currency', 'CRNC') {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
