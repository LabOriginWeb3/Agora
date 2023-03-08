// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IAgoraHub} from './IAgoraHub.sol';
import {Proxy} from './Proxy.sol';
import {Address} from './Address.sol';

contract FollowNFTProxy is Proxy {
    using Address for address;
    address immutable HUB;

    constructor(bytes memory data) {
        HUB = msg.sender;
        IAgoraHub(msg.sender).getFollowNFTImpl().functionDelegateCall(data);
    }

    function _implementation() internal view override returns (address) {
        return IAgoraHub(HUB).getFollowNFTImpl();
    }
}
