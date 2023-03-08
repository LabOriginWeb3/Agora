// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from './DataTypes.sol';

abstract contract AgoraHubStorage {

    mapping(address => bool) internal _followModuleWhitelisted;
    mapping(address => bool) internal _collectModuleWhitelisted;
    mapping(address => bool) internal _referenceModuleWhitelisted;

    mapping(uint256 => address) internal _dispatcherByProfile;
    mapping(bytes32 => uint256) internal _profileIdByHandleHash;
    mapping(uint256 => DataTypes.ProfileStruct) internal _profileById;
    mapping(uint256 => mapping(uint256 => DataTypes.PublicationStruct)) internal _pubByIdByProfile;

    mapping(address => uint256) internal _defaultProfileByAddress;
     mapping(uint256 => mapping(uint256 => DataTypes.ContentScoreStruct)) internal _scoreByPubIdByProfile;
     mapping(uint256 => DataTypes.ReputationFactors) public _currReputationFactors;
     mapping(uint256 => int256[7]) public _currActionFactors;
     mapping(uint256 => mapping(uint256 => mapping(address => bool))) internal _isUserCommented;
     mapping(uint256 => mapping(uint256 => mapping(address => bool))) internal _isUserLiked;
     mapping(uint256 => mapping(uint256 => mapping(address => bool))) internal _isUserUpvoted;
     mapping(uint256 => mapping(uint256 => mapping(address => bool))) internal _isUserDownvoted;
     mapping(uint256 => mapping(uint256 => mapping(address => bool))) internal _isUserReported;
     mapping(uint256 => mapping(uint256 => mapping(address => bool))) internal _isUserCollected;
     mapping(uint256 => mapping(uint256 => mapping(address => bool))) internal _isUserMirrored;

    uint256 internal _profileCounter;
    address internal _governance;
    address internal _emergencyAdmin;
}
