// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IAgoraHub} from "./IAgoraHub.sol";
import {Events} from "./Events.sol";
import {Helpers} from "./Helpers.sol";
import {Constants} from "./Constants.sol";
import {DataTypes} from "./DataTypes.sol";
import {Errors} from "./Errors.sol";
import {PublishingLogic} from "./PublishingLogic.sol";
import {ProfileTokenURILogic} from "./ProfileTokenURILogic.sol";
import {InteractionLogic} from "./InteractionLogic.sol";
import {AgoraNFTBase} from "./AgoraNFTBase.sol";
import {AgoraMultiState} from "./AgoraMultiState.sol";
import {AgoraHubStorage} from "./AgoraHubStorage.sol";
import {IERC721Enumerable} from "./IERC721Enumerable.sol";
import {IERC20} from "./IERC20.sol";

contract AgoraHub is AgoraNFTBase, AgoraMultiState, AgoraHubStorage, IAgoraHub {
    uint256 internal constant REVISION = 1;

    address internal immutable FOLLOW_NFT_IMPL;
    address internal immutable COLLECT_NFT_IMPL;

    /**
     * @dev This modifier reverts if the caller is not the configured governance address.
     */
    modifier onlyGov() {
        _validateCallerIsGovernance();
        _;
    }

    /**
     * @dev The constructor sets the immutable follow & collect NFT implementations.
     *
     * @param followNFTImpl The follow NFT implementation address.
     * @param collectNFTImpl The collect NFT implementation address.
     */
    constructor(address followNFTImpl, address collectNFTImpl) {
        if (followNFTImpl == address(0)) revert Errors.InitParamsInvalid();
        if (collectNFTImpl == address(0)) revert Errors.InitParamsInvalid();
        FOLLOW_NFT_IMPL = followNFTImpl;
        COLLECT_NFT_IMPL = collectNFTImpl;
    }

    function initialize(
        string calldata name,
        string calldata symbol,
        address newGovernance
    ) external override {
        super._initialize(name, symbol);
        _setState(DataTypes.ProtocolState.Paused);
        _setGovernance(newGovernance);
    }

    function setGovernance(address newGovernance) external override onlyGov {
        _setGovernance(newGovernance);
    }

    function setEmergencyAdmin(address newEmergencyAdmin)
        external
        override
        onlyGov
    {
        address prevEmergencyAdmin = _emergencyAdmin;
        _emergencyAdmin = newEmergencyAdmin;
        emit Events.EmergencyAdminSet(
            msg.sender,
            prevEmergencyAdmin,
            newEmergencyAdmin,
            block.timestamp
        );
    }

    function setState(DataTypes.ProtocolState newState) external override {
        if (msg.sender == _emergencyAdmin) {
            if (newState == DataTypes.ProtocolState.Unpaused)
                revert Errors.EmergencyAdminCannotUnpause();
            _validateNotPaused();
        } else if (msg.sender != _governance) {
            revert Errors.NotGovernanceOrEmergencyAdmin();
        }
        _setState(newState);
    }

    function whitelistFollowModule(address followModule, bool whitelist)
        external
        override
        onlyGov
    {
        _followModuleWhitelisted[followModule] = whitelist;
        emit Events.FollowModuleWhitelisted(
            followModule,
            whitelist,
            block.timestamp
        );
    }

    function whitelistReferenceModule(address referenceModule, bool whitelist)
        external
        override
        onlyGov
    {
        _referenceModuleWhitelisted[referenceModule] = whitelist;
        emit Events.ReferenceModuleWhitelisted(
            referenceModule,
            whitelist,
            block.timestamp
        );
    }

    function whitelistCollectModule(address collectModule, bool whitelist)
        external
        override
        onlyGov
    {
        _collectModuleWhitelisted[collectModule] = whitelist;
        emit Events.CollectModuleWhitelisted(
            collectModule,
            whitelist,
            block.timestamp
        );
    }

    function withdrawToken(address token, uint256 amount)
        external
        override
        onlyGov
    {
        IERC20(token).transfer(_governance, amount);
        emit Events.WithdrawToken(_governance, amount, block.timestamp);
    }

    /// @inheritdoc IAgoraHub
    function createProfile(DataTypes.CreateProfileData calldata vars)
        external
        override
        whenNotPaused
        returns (uint256)
    {
        unchecked {
            uint256 profileId = ++_profileCounter;
            _mint(vars.to, profileId);
            PublishingLogic.createProfile(
                vars,
                profileId,
                _profileIdByHandleHash,
                _profileById,
                _followModuleWhitelisted
            );
            return profileId;
        }
    }

    function setDefaultProfile(uint256 profileId)
        external
        override
        whenNotPaused
    {
        _setDefaultProfile(msg.sender, profileId);
    }

    function setFollowModule(
        uint256 profileId,
        address followModule,
        bytes calldata followModuleInitData
    ) external override whenNotPaused {
        _validateCallerIsProfileOwner(profileId);
        PublishingLogic.setFollowModule(
            profileId,
            followModule,
            followModuleInitData,
            _profileById[profileId],
            _followModuleWhitelisted
        );
    }

    function setDispatcher(uint256 profileId, address dispatcher)
        external
        override
        whenNotPaused
    {
        _validateCallerIsProfileOwner(profileId);
        _setDispatcher(profileId, dispatcher);
    }

    function setProfileImageURI(uint256 profileId, string calldata imageURI)
        external
        override
        whenNotPaused
    {
        _validateCallerIsProfileOwnerOrDispatcher(profileId);
        _setProfileImageURI(profileId, imageURI);
    }

    function setFollowNFTURI(uint256 profileId, string calldata followNFTURI)
        external
        override
        whenNotPaused
    {
        _validateCallerIsProfileOwnerOrDispatcher(profileId);
        _setFollowNFTURI(profileId, followNFTURI);
    }

    function post(DataTypes.PostData calldata vars)
        external
        override
        whenPublishingEnabled
        returns (uint256)
    {
        _validateCallerIsProfileOwnerOrDispatcher(vars.profileId);
        return _createPost(vars);
    }

    function comment(DataTypes.CommentData calldata vars)
        external
        override
        whenPublishingEnabled
        returns (uint256)
    {
        _validateCallerIsProfileOwnerOrDispatcher(vars.profileId);
        return _createComment(vars);
    }

    function mirror(DataTypes.MirrorData calldata vars)
        external
        override
        whenPublishingEnabled
        returns (uint256)
    {
        _validateCallerIsProfileOwnerOrDispatcher(vars.profileId);
        return _createMirror(vars);
    }

    function burn(uint256 tokenId) public override whenNotPaused {
        super.burn(tokenId);
        _clearHandleHash(tokenId);
    }

    function follow(uint256[] calldata profileIds, bytes[] calldata datas)
        external
        override
        whenNotPaused
        returns (uint256[] memory)
    {
        return
            InteractionLogic.follow(
                msg.sender,
                address(this),
                profileIds,
                datas,
                _profileById,
                _profileIdByHandleHash
            );
    }

    function collect(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external override whenNotPaused returns (uint256) {
        return
            InteractionLogic.collect(
                msg.sender,
                profileId,
                pubId,
                data,
                [COLLECT_NFT_IMPL, address(this)],
                _pubByIdByProfile,
                _profileById
            );
    }

    function vote(
        uint256 profileId,
        uint256 pubId,
        int8 amount
    ) external override whenNotPaused {
        if (
            _isUserUpvoted[profileId][pubId][msg.sender] ||
            _isUserDownvoted[profileId][pubId][msg.sender]
        ) {
            revert Errors.AlreadyVoted();
        }
        return
            InteractionLogic.vote(
                msg.sender,
                profileId,
                pubId,
                amount,
                _pubByIdByProfile
            );
    }

    function stake(
        uint256 stakerProfileId,
        uint256 profileId,
        uint256 pubId,
        DataTypes.StakeType stakeType,
        uint256 amount,
        address stakeToken
    ) external override whenNotPaused {
        IERC20(stakeToken).transferFrom(msg.sender, address(this), amount);
        return
            InteractionLogic.stake(
                stakerProfileId,
                profileId,
                pubId,
                stakeType,
                amount,
                _pubByIdByProfile,
                _profileById
            );
    }

    function getContentScore(uint256 profileId, uint256 pubId)
        public
        view
        returns (int256)
    {
        return _pubByIdByProfile[profileId][pubId].score;
    }

    function _updateContentScore(
        uint256 profileId,
        uint256 pubId,
        DataTypes.ActionType actionType
    ) private {
        DataTypes.ContentScoreStruct storage scoreInfo = _scoreByPubIdByProfile[
            profileId
        ][pubId];
        int256 oldScore = scoreInfo.totalScore;
        int256 changeScore = _updatePartScoreByAction(
            uint256(actionType),
            profileId,
            pubId
        );
        if (changeScore == 0) return;
        _scoreByPubIdByProfile[profileId][pubId].totalScore =
            oldScore +
            changeScore;
        _profileById[profileId].totalContentScores += changeScore;
        _pubByIdByProfile[profileId][pubId].score = oldScore + changeScore;
    }

    function _updatePartScoreByAction(
        uint256 actionType,
        uint256 profileId,
        uint256 pubId
    ) private view returns (int256) {
        int256 changeScore = 1;
        // switch case
        // bool value0 =  _isUserCommented[profileId][pubId][msg.sender];
        // bool value1 =  _isUserLiked[profileId][pubId][msg.sender];
        // bool value2 =  _isUserUpvoted[profileId][pubId][msg.sender];
        // bool value3 =  _isUserDownvoted[profileId][pubId][msg.sender];
        // bool value4 =  _isUserReported[profileId][pubId][msg.sender];
        // bool value5 =  _isUserCollected[profileId][pubId][msg.sender];
        // bool value6 =  _isUserMirrored[profileId][pubId][msg.sender];
        // assembly{
        //     switch actionType
        //     case 0 {
        //         if eq(value0, true) {
        //             changeScore :=0
        //         }
        //     }
        //     case 1 {
        //         if eq(value1, true) {
        //             changeScore :=0
        //         }
        //     }
        //     case 2 {
        //         if eq(value2, true) {
        //             changeScore :=0
        //         }
        //     }
        //     case 3 {
        //         if eq(value3, true) {
        //             changeScore :=0
        //         }
        //     }
        //     case 4 {
        //         if eq(value4, true) {
        //             changeScore :=0
        //         }
        //     }
        //     case 5 {
        //         if eq(value5, true) {
        //             changeScore :=0
        //         }
        //     }
        //     case 6 {
        //         if eq(value6, true) {
        //             changeScore :=0
        //         }
        //     }
        // }
        if (changeScore == 0) return 0;

        uint256 userLevel = getUserLevel(profileId);
        changeScore =
            _currActionFactors[REVISION][actionType] *
            int256(2**userLevel);

        return changeScore;
    }

    function getUserReputation(uint256 profileId) public view returns (int256) {
        DataTypes.ReputationFactors storage factors = _currReputationFactors[
            REVISION
        ];
        int256 reputation = int256(
            getUserTotalContentsScore(profileId) * factors.contentScore
        ) +
            int256(int256(_profileById[profileId].answers) * factors.answers) +
            int256(
                (int256(_profileById[profileId].successRecommend) /
                    int256(_profileById[profileId].recommend)) *
                    factors.stakeSuccess
            );
        return reputation;
    }

    function getUserLevel(uint256 profileId) public view returns (uint256) {
        int256 Reputation = getUserReputation(profileId);
        // if()
        return 1;
    }

    function getUserTotalContentsScore(uint256 profileId)
        public
        view
        returns (int256)
    {
        return _profileById[profileId].totalContentScores;
    }

    // function bet(
    //     uint256 profileId,
    //     uint256 pubId,
    //     int8 amount
    // ) external override whenNotPaused {
    //     return
    //         InteractionLogic.vote(
    //             msg.sender,
    //             profileId,
    //             pubId,
    //             amount,
    //             _pubByIdByProfile
    //         );
    // }

    function emitFollowNFTTransferEvent(
        uint256 profileId,
        uint256 followNFTId,
        address from,
        address to
    ) external override {
        address expectedFollowNFT = _profileById[profileId].followNFT;
        if (msg.sender != expectedFollowNFT) revert Errors.CallerNotFollowNFT();
        emit Events.FollowNFTTransferred(
            profileId,
            followNFTId,
            from,
            to,
            block.timestamp
        );
    }

    function emitCollectNFTTransferEvent(
        uint256 profileId,
        uint256 pubId,
        uint256 collectNFTId,
        address from,
        address to
    ) external override {
        address expectedCollectNFT = _pubByIdByProfile[profileId][pubId]
            .collectNFT;
        if (msg.sender != expectedCollectNFT)
            revert Errors.CallerNotCollectNFT();
        emit Events.CollectNFTTransferred(
            profileId,
            pubId,
            collectNFTId,
            from,
            to,
            block.timestamp
        );
    }

    function defaultProfile(address wallet)
        external
        view
        override
        returns (uint256)
    {
        return _defaultProfileByAddress[wallet];
    }

    function isFollowModuleWhitelisted(address followModule)
        external
        view
        override
        returns (bool)
    {
        return _followModuleWhitelisted[followModule];
    }

    function isReferenceModuleWhitelisted(address referenceModule)
        external
        view
        override
        returns (bool)
    {
        return _referenceModuleWhitelisted[referenceModule];
    }

    function isCollectModuleWhitelisted(address collectModule)
        external
        view
        override
        returns (bool)
    {
        return _collectModuleWhitelisted[collectModule];
    }

    function getGovernance() external view override returns (address) {
        return _governance;
    }

    function getDispatcher(uint256 profileId)
        external
        view
        override
        returns (address)
    {
        return _dispatcherByProfile[profileId];
    }

    function getPubCount(uint256 profileId)
        public
        view
        override
        returns (uint256)
    {
        return _profileById[profileId].pubCount;
    }

    function getFollowNFT(uint256 profileId)
        external
        view
        override
        returns (address)
    {
        return _profileById[profileId].followNFT;
    }

    function getFollowNFTURI(uint256 profileId)
        external
        view
        override
        returns (string memory)
    {
        return _profileById[profileId].followNFTURI;
    }

    function getCollectNFT(uint256 profileId, uint256 pubId)
        external
        view
        override
        returns (address)
    {
        return _pubByIdByProfile[profileId][pubId].collectNFT;
    }

    function getFollowModule(uint256 profileId)
        external
        view
        override
        returns (address)
    {
        return _profileById[profileId].followModule;
    }

    function getCollectModule(uint256 profileId, uint256 pubId)
        external
        view
        override
        returns (address)
    {
        return _pubByIdByProfile[profileId][pubId].collectModule;
    }

    function getReferenceModule(uint256 profileId, uint256 pubId)
        external
        view
        override
        returns (address)
    {
        return _pubByIdByProfile[profileId][pubId].referenceModule;
    }

    function getHandle(uint256 profileId)
        external
        view
        override
        returns (string memory)
    {
        return _profileById[profileId].handle;
    }

    function getPubPointer(uint256 profileId, uint256 pubId)
        external
        view
        override
        returns (uint256, uint256)
    {
        uint256 profileIdPointed = _pubByIdByProfile[profileId][pubId]
            .profileIdPointed;
        uint256 pubIdPointed = _pubByIdByProfile[profileId][pubId].pubIdPointed;
        return (profileIdPointed, pubIdPointed);
    }

    function getContentURI(uint256 profileId, uint256 pubId)
        external
        view
        override
        returns (string memory)
    {
        (uint256 rootProfileId, uint256 rootPubId, ) = Helpers
            .getPointedIfMirror(profileId, pubId, _pubByIdByProfile);
        return _pubByIdByProfile[rootProfileId][rootPubId].contentURI;
    }

    function getProfileIdByHandle(string calldata handle)
        external
        view
        override
        returns (uint256)
    {
        bytes32 handleHash = keccak256(bytes(handle));
        return _profileIdByHandleHash[handleHash];
    }

    function getProfile(uint256 profileId)
        external
        view
        override
        returns (DataTypes.ProfileStruct memory)
    {
        // _profileById[profileId].reputation = getReputationByProfileId(profileId);
        return _profileById[profileId];
    }

    // function getReputationByProfileId(uint256 profileId)
    //     public
    //     view
    //     returns (int256)
    // {
    //     // _profileById[profileId].reputation = getReputationByProfileId;
    //     int256 reputation = 0;
    //     return reputation;
    // }

    function getPub(uint256 profileId, uint256 pubId)
        external
        view
        override
        returns (DataTypes.PublicationStruct memory)
    {
        return _pubByIdByProfile[profileId][pubId];
    }

    function getPubType(uint256 profileId, uint256 pubId)
        external
        view
        override
        returns (DataTypes.PubType)
    {
        if (pubId == 0 || _profileById[profileId].pubCount < pubId) {
            return DataTypes.PubType.Nonexistent;
        } else if (
            _pubByIdByProfile[profileId][pubId].collectModule == address(0)
        ) {
            return DataTypes.PubType.Mirror;
        } else if (_pubByIdByProfile[profileId][pubId].profileIdPointed == 0) {
            return DataTypes.PubType.Post;
        } else {
            return DataTypes.PubType.Comment;
        }
    }

    /**
     * @dev Overrides the ERC721 tokenURI function to return the associated URI with a given profile.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        address followNFT = _profileById[tokenId].followNFT;
        return
            ProfileTokenURILogic.getProfileTokenURI(
                tokenId,
                followNFT == address(0)
                    ? 0
                    : IERC721Enumerable(followNFT).totalSupply(),
                ownerOf(tokenId),
                _profileById
            );
    }

    function getFollowNFTImpl() external view override returns (address) {
        return FOLLOW_NFT_IMPL;
    }

    function getCollectNFTImpl() external view override returns (address) {
        return COLLECT_NFT_IMPL;
    }

    function _setGovernance(address newGovernance) internal {
        address prevGovernance = _governance;
        _governance = newGovernance;
        emit Events.GovernanceSet(
            msg.sender,
            prevGovernance,
            newGovernance,
            block.timestamp
        );
    }

    function _createPost(DataTypes.PostData calldata vars)
        internal
        returns (uint256)
    {
        unchecked {
            uint256 pubId = ++_profileById[vars.profileId].pubCount;
            PublishingLogic.createPost(
                vars,
                pubId,
                _pubByIdByProfile,
                _collectModuleWhitelisted,
                _referenceModuleWhitelisted,
                _profileById
            );
            return pubId;
        }
    }

    function _setDefaultProfile(address wallet, uint256 profileId) internal {
        if (profileId > 0 && wallet != ownerOf(profileId))
            revert Errors.NotProfileOwner();

        _defaultProfileByAddress[wallet] = profileId;

        emit Events.DefaultProfileSet(wallet, profileId, block.timestamp);
    }

    function _createComment(DataTypes.CommentData memory vars)
        internal
        returns (uint256)
    {
        unchecked {
            uint256 pubId = ++_profileById[vars.profileId].pubCount;
            PublishingLogic.createComment(
                vars,
                pubId,
                _profileById,
                _pubByIdByProfile,
                _collectModuleWhitelisted,
                _referenceModuleWhitelisted
            );
            return pubId;
        }
    }

    function _createMirror(DataTypes.MirrorData memory vars)
        internal
        returns (uint256)
    {
        unchecked {
            uint256 pubId = ++_profileById[vars.profileId].pubCount;
            PublishingLogic.createMirror(
                vars,
                pubId,
                _pubByIdByProfile,
                _referenceModuleWhitelisted
            );
            return pubId;
        }
    }

    function _setDispatcher(uint256 profileId, address dispatcher) internal {
        _dispatcherByProfile[profileId] = dispatcher;
        emit Events.DispatcherSet(profileId, dispatcher, block.timestamp);
    }

    function _setProfileImageURI(uint256 profileId, string calldata imageURI)
        internal
    {
        if (bytes(imageURI).length > Constants.MAX_PROFILE_IMAGE_URI_LENGTH)
            revert Errors.ProfileImageURILengthInvalid();
        _profileById[profileId].imageURI = imageURI;
        emit Events.ProfileImageURISet(profileId, imageURI, block.timestamp);
    }

    function _setFollowNFTURI(uint256 profileId, string calldata followNFTURI)
        internal
    {
        _profileById[profileId].followNFTURI = followNFTURI;
        emit Events.FollowNFTURISet(profileId, followNFTURI, block.timestamp);
    }

    function _clearHandleHash(uint256 profileId) internal {
        bytes32 handleHash = keccak256(bytes(_profileById[profileId].handle));
        _profileIdByHandleHash[handleHash] = 0;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override whenNotPaused {
        if (_dispatcherByProfile[tokenId] != address(0)) {
            _setDispatcher(tokenId, address(0));
        }

        if (_defaultProfileByAddress[from] == tokenId) {
            _defaultProfileByAddress[from] = 0;
        }

        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _validateCallerIsProfileOwnerOrDispatcher(uint256 profileId)
        internal
        view
    {
        if (
            msg.sender == ownerOf(profileId) ||
            msg.sender == _dispatcherByProfile[profileId]
        ) {
            return;
        }
        revert Errors.NotProfileOwnerOrDispatcher();
    }

    function _validateCallerIsProfileOwner(uint256 profileId) internal view {
        if (msg.sender != ownerOf(profileId)) revert Errors.NotProfileOwner();
    }

    function _validateCallerIsGovernance() internal view {
        if (msg.sender != _governance) revert Errors.NotGovernance();
    }
}
