// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IReferenceModule} from './IReferenceModule.sol';
import {ModuleBase} from './ModuleBase.sol';
import {FollowValidationModuleBase} from './FollowValidationModuleBase.sol';
import {IERC721} from './IERC721.sol';


contract FollowerOnlyReferenceModule is FollowValidationModuleBase, IReferenceModule {
    constructor(address hub) ModuleBase(hub) {}

    /**
     * @dev There is nothing needed at initialization.
     */
    function initializeReferenceModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external pure override returns (bytes memory) {
        return new bytes(0);
    }

    /**
     * @notice Validates that the commenting profile's owner is a follower.
     *
     * NOTE: We don't need to care what the pointed publication is in this context.
     */
    function processComment(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed,
        bytes calldata data
    ) external view override {
        address commentCreator = IERC721(HUB).ownerOf(profileId);
        _checkFollowValidity(profileIdPointed, commentCreator);
    }

    /**
     * @notice Validates that the commenting profile's owner is a follower.
     *
     * NOTE: We don't need to care what the pointed publication is in this context.
     */
    function processMirror(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed,
        bytes calldata data
    ) external view override {
        address mirrorCreator = IERC721(HUB).ownerOf(profileId);
        _checkFollowValidity(profileIdPointed, mirrorCreator);
    }
}
