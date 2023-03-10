// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {FollowNFTProxy} from "./FollowNFTProxy.sol";
import {Helpers} from "./Helpers.sol";
import {DataTypes} from "./DataTypes.sol";
import {Errors} from "./Errors.sol";
import {Events} from "./Events.sol";
import {Constants} from "./Constants.sol";
import {IFollowNFT} from "./IFollowNFT.sol";
import {ICollectNFT} from "./ICollectNFT.sol";
import {IFollowModule} from "./IFollowModule.sol";
import {ICollectModule} from "./ICollectModule.sol";
import {Clones} from "./Clones.sol";
import {Strings} from "./Strings.sol";

/**
 * @title InteractionLogic
 * @author Agora Protocol
 *
 * @notice This is the library that contains the logic for follows & collects. 
 
 * @dev The functions are external, so they are called from the hub via `delegateCall` under the hood.
 */
library InteractionLogic {
    using Strings for uint256;

    /**
     * @notice Follows the given profiles, executing the necessary logic and module calls before minting the follow
     * NFT(s) to the follower.
     *
     * @param follower The address executing the follow.
     * @param profileIds The array of profile token IDs to follow.
     * @param followModuleDatas The array of follow module data parameters to pass to each profile's follow module.
     * @param _profileById A pointer to the storage mapping of profile structs by profile ID.
     * @param _profileIdByHandleHash A pointer to the storage mapping of profile IDs by handle hash.
     *
     * @return uint256[] An array of integers representing the minted follow NFTs token IDs.
     */
    function follow(
        address follower,
        address hub,
        uint256[] calldata profileIds,
        bytes[] calldata followModuleDatas,
        mapping(uint256 => DataTypes.ProfileStruct) storage _profileById,
        mapping(bytes32 => uint256) storage _profileIdByHandleHash
    ) external returns (uint256[] memory) {
        if (profileIds.length != followModuleDatas.length)
            revert Errors.ArrayMismatch();
        uint256[] memory tokenIds = new uint256[](profileIds.length);
        for (uint256 i = 0; i < profileIds.length; ) {
            string memory handle = _profileById[profileIds[i]].handle;
            if (
                _profileIdByHandleHash[keccak256(bytes(handle))] !=
                profileIds[i]
            ) revert Errors.TokenDoesNotExist();

            address followModule = _profileById[profileIds[i]].followModule;
            address followNFT = _profileById[profileIds[i]].followNFT;

            if (followNFT == address(0)) {
                followNFT = _deployFollowNFT(profileIds[i], hub);
                _profileById[profileIds[i]].followNFT = followNFT;
            }

            tokenIds[i] = IFollowNFT(followNFT).mint(follower);

            if (followModule != address(0)) {
                IFollowModule(followModule).processFollow(
                    follower,
                    profileIds[i],
                    followModuleDatas[i]
                );
            }
            unchecked {
                ++i;
            }
        }
        emit Events.Followed(
            follower,
            profileIds,
            followModuleDatas,
            block.timestamp
        );
        return tokenIds;
    }

    /**
     * @notice Collects the given publication, executing the necessary logic and module call before minting the
     * collect NFT to the collector.
     *
     * @param collector The address executing the collect.
     * @param profileId The token ID of the publication being collected's parent profile.
     * @param pubId The publication ID of the publication being collected.
     * @param collectModuleData The data to pass to the publication's collect module.
     * @param _pubByIdByProfile A pointer to the storage mapping of publications by pubId by profile ID.
     * @param _profileById A pointer to the storage mapping of profile structs by profile ID.
     *
     * @return uint256 An integer representing the minted token ID.
     */
    function collect(
        address collector,
        uint256 profileId,
        uint256 pubId,
        bytes calldata collectModuleData,
        address[2] calldata caddr,
        mapping(uint256 => mapping(uint256 => DataTypes.PublicationStruct))
            storage _pubByIdByProfile,
        mapping(uint256 => DataTypes.ProfileStruct) storage _profileById
    ) external returns (uint256) {
        (
            uint256 rootProfileId,
            uint256 rootPubId,
            address rootCollectModule
        ) = Helpers.getPointedIfMirror(profileId, pubId, _pubByIdByProfile);

        uint256 tokenId;
        // Avoids stack too deep
        {
            address collectNFT = _pubByIdByProfile[rootProfileId][rootPubId]
                .collectNFT;
            if (collectNFT == address(0)) {
                collectNFT = _deployCollectNFT(
                    rootProfileId,
                    rootPubId,
                    _profileById[rootProfileId].handle,
                    caddr[0],
                    caddr[1]
                );
                _pubByIdByProfile[rootProfileId][rootPubId]
                    .collectNFT = collectNFT;
            }
            tokenId = ICollectNFT(collectNFT).mint(collector);
        }

        ICollectModule(rootCollectModule).processCollect(
            profileId,
            collector,
            rootProfileId,
            rootPubId,
            collectModuleData
        );
        _emitCollectedEvent(
            collector,
            profileId,
            pubId,
            rootProfileId,
            rootPubId,
            collectModuleData
        );

        return tokenId;
    }

    function vote(
        address voter,
        uint256 profileId,
        uint256 pubId,
        int8 amount,
        mapping(uint256 => mapping(uint256 => DataTypes.PublicationStruct))
            storage _pubByIdByProfile
    ) external {
        amount > 0
            ? _pubByIdByProfile[profileId][pubId].upvotes++
            : _pubByIdByProfile[profileId][pubId].downvotes;
        _emitVotedEvent(voter, profileId, pubId, amount);
    }

    function stake(
        uint256 stakerProfileId,
        uint256 profileId,
        uint256 pubId,
        DataTypes.StakeType stakeType,
        uint256 amount,
        mapping(uint256 => mapping(uint256 => DataTypes.PublicationStruct))
            storage _pubByIdByProfile,
        mapping(uint256 => DataTypes.ProfileStruct) storage _profileById
    ) external {
        if (stakeType == DataTypes.StakeType.Boost) {
            _profileById[stakerProfileId].bet++;
            //    _profileById[stakerProfileId].interactedContents;
            //    _profileById[stakerProfileId].boostedContents;
            _pubByIdByProfile[profileId][pubId].boostAmount += amount;
        } else {}

        _emitStakedEvent(msg.sender, profileId, pubId, amount, stakeType);
    }

    /**
     * @notice Deploys the given profile's Follow NFT contract.
     *
     * @param profileId The token ID of the profile which Follow NFT should be deployed.
     *
     * @return address The address of the deployed Follow NFT contract.
     */
    function _deployFollowNFT(uint256 profileId, address hub)
        private
        returns (address)
    {
        bytes memory functionData = abi.encodeWithSelector(
            IFollowNFT.initialize.selector,
            profileId,
            hub
        );
        address followNFT = address(new FollowNFTProxy(functionData));
        emit Events.FollowNFTDeployed(profileId, followNFT, block.timestamp);

        return followNFT;
    }

    /**
     * @notice Deploys the given profile's Collect NFT contract.
     *
     * @param profileId The token ID of the profile which Collect NFT should be deployed.
     * @param pubId The publication ID of the publication being collected, which Collect NFT should be deployed.
     * @param handle The profile's associated handle.
     * @param collectNFTImpl The address of the Collect NFT implementation that should be used for the deployment.
     *
     * @return address The address of the deployed Collect NFT contract.
     */
    function _deployCollectNFT(
        uint256 profileId,
        uint256 pubId,
        string memory handle,
        address collectNFTImpl,
        address hub
    ) private returns (address) {
        address collectNFT = Clones.clone(collectNFTImpl);

        bytes4 firstBytes = bytes4(bytes(handle));

        string memory collectNFTName = string(
            abi.encodePacked(
                handle,
                Constants.COLLECT_NFT_NAME_INFIX,
                pubId.toString()
            )
        );
        string memory collectNFTSymbol = string(
            abi.encodePacked(
                firstBytes,
                Constants.COLLECT_NFT_SYMBOL_INFIX,
                pubId.toString()
            )
        );

        ICollectNFT(collectNFT).initialize(
            profileId,
            pubId,
            hub,
            collectNFTName,
            collectNFTSymbol
        );
        emit Events.CollectNFTDeployed(
            profileId,
            pubId,
            collectNFT,
            block.timestamp
        );

        return collectNFT;
    }

    /**
     * @notice Emits the `Collected` event that signals that a successful collect action has occurred.
     *
     * @dev This is done through this function to prevent stack too deep compilation error.
     *
     * @param collector The address collecting the publication.
     * @param profileId The token ID of the profile that the collect was initiated towards, useful to differentiate mirrors.
     * @param pubId The publication ID that the collect was initiated towards, useful to differentiate mirrors.
     * @param rootProfileId The profile token ID of the profile whose publication is being collected.
     * @param rootPubId The publication ID of the publication being collected.
     * @param data The data passed to the collect module.
     */
    function _emitCollectedEvent(
        address collector,
        uint256 profileId,
        uint256 pubId,
        uint256 rootProfileId,
        uint256 rootPubId,
        bytes calldata data
    ) private {
        emit Events.Collected(
            collector,
            profileId,
            pubId,
            rootProfileId,
            rootPubId,
            data,
            block.timestamp
        );
    }

    function _emitVotedEvent(
        address voter,
        uint256 profileId,
        uint256 pubId,
        int8 amount
    ) private {
        emit Events.Voted(voter, profileId, pubId, amount, block.timestamp);
    }

    function _emitStakedEvent(
        address staker,
        uint256 profileId,
        uint256 pubId,
        uint256 amount,
        DataTypes.StakeType stakeType
    ) private {
        emit Events.Staked(
            staker,
            profileId,
            pubId,
            amount,
            stakeType,
            block.timestamp
        );
    }
}
