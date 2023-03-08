// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @title DataTypes
 * @author Agora Protocol
 *
 * @notice A standard library of data types used throughout the Agora Protocol.
 */
library DataTypes {
    /**
     * @notice An enum containing the different states the protocol can be in, limiting certain actions.
     *
     * @param Unpaused The fully unpaused state.
     * @param PublishingPaused The state where only publication creation functions are paused.
     * @param Paused The fully paused state.
     */
    enum ProtocolState {
        Unpaused,
        PublishingPaused,
        Paused
    }

    /**
     * @notice An enum specifically used in a helper function to easily retrieve the publication type for integrations.
     *
     * @param Post A standard post, having a URI, a collect module but no pointer to another publication.
     * @param Comment A comment, having a URI, a collect module and a pointer to another publication.
     * @param Mirror A mirror, having a pointer to another publication, but no URI or collect module.
     * @param Nonexistent An indicator showing the queried publication does not exist.
     */
    enum PubType {
        Post,
        Comment,
        Mirror,
        Nonexistent
    }

    enum ContentType {
        Question,
        BetQuestion,
        AD,
        Answer,
        BetAnswer
    }

    enum StakeType {
        Boost,
        Bet
    }

    enum ActionType {
        Post,
        Comment,
        Like,
        Upvote,
        Downvote,
        Report,
        Collect,
        Mirror
    }

    struct ReputationFactors {
        int256  contentScore;
        int256  answers;
        int256  stakeSuccess;
    }

    struct ActionFactors {
        int256 Comment;
        int256 Like;
        int256 Upvote;
        int256 Downvote;
        int256 Report;
        int256 Collect;
        int256 Mirror;
    }

    struct ProfileStruct {
        uint256 pubCount;// feeds
        address followModule;
        address followNFT;
        string handle; // username
        string imageURI; // photo
        int256 reputation;
        uint8 gender;
        string education;
        string company;
        string bio;
        string email;
        string twitter; // Id&Name,
        string discord; // Id&Name,
        string interests;
        string link;
        string location;
        uint256 agoraProfileId;// profileId

        uint256 successRecommend;
        uint256 recommend;
        uint256 successBet;
        uint256 bet;
        string boostedContents;
        string betContents;
        string interactedContents;
        uint256 answers;
        uint256 collects;
        uint256 questions;
        uint256 collected;
        uint256 mirrored;
        string followNFTURI;
        int256 totalContentScores;
    }

    struct PublicationStruct {
        uint256 profileId;
        uint256 profileIdPointed;
        uint256 pubIdPointed;
        string contentURI;
        address collectModule;
        bytes collectModuleInitData;
        address referenceModule;
        bytes referenceModuleInitData;
        address collectNFT;
        uint256 upvotes;
        uint256 downvotes;
        uint256 comments;
        int256 score;
        ContentType contentType; 
        string options;
        uint256 betDeadline;
        bool advertisement;
        uint256 adDeadline;
        int256 adScore;
        uint256 reports;
        uint256 boostAmount;
        uint256 betAmount;
        uint256 betDetailAmount;
        uint256 stakers;
        uint256 collected;
        uint8 correctOption;
    }


    struct CreateProfileData {
        address to;
        string handle;
        string imageURI;
        int256 reputation;
        uint8 gender;
        string education;
        string company;
        string bio;
        string email;
        string twitter;
        string discord;
        string interests;
        string link;
        string location;
        uint256 lensProfileId;
        
        address followModule;
        bytes followModuleInitData;
        string followNFTURI;
    }

    struct PostData {
        uint256 profileId;
        string contentURI;
        address collectModule;
        bytes collectModuleInitData;
        address referenceModule;
        bytes referenceModuleInitData;
        ContentType contentType;
        string options;
        uint256 betDeadline;
        bool advertisement;
        uint256 adDeadline;
    }

    struct CommentData {
        uint256 profileId;
        string contentURI;
        uint256 profileIdPointed;
        uint256 pubIdPointed;
        bytes referenceModuleData;
        address collectModule;
        bytes collectModuleInitData;
        address referenceModule;
        bytes referenceModuleInitData;
        ContentType contentType;
    }

    /**
     * @notice A struct containing the parameters required for the `mirror()` function.
     *
     * @param profileId The token ID of the profile to publish to.
     * @param profileIdPointed The profile token ID to point the mirror to.
     * @param pubIdPointed The publication ID to point the mirror to.
     * @param referenceModuleData The data passed to the reference module.
     * @param referenceModule The reference module to set for the given publication, must be whitelisted.
     * @param referenceModuleInitData The data to be passed to the reference module for initialization.
     */
    struct MirrorData {
        uint256 profileId;
        uint256 profileIdPointed;
        uint256 pubIdPointed;
        bytes referenceModuleData;
        address referenceModule;
        bytes referenceModuleInitData;
    }

    
    struct StakeStruct {
        uint256 profileId;
        uint256 profileIdPointed;
        uint256 pubIdPointed;
        address token;
        uint256 stakeAmount;
        uint256 stakeTime;
        uint256 contentScoreAtStakeTime;

    }

    
    struct ContentScoreStruct {
        
        int256 commentScore;
        int256 likeScore;
        int256 upvoteScore;
        int256 downvoteScore;
        int256 reportScore;
        int256 collectScore;
        int256 mirrorScore;
        int256 totalScore;
    }

    struct ContentDetailInfo{
        mapping(uint8 => uint256) CommentsInfo;
        mapping(uint8 => uint256) LikesInfo;
        mapping(uint8 => uint256) UpvotesInfo;
        mapping(uint8 => uint256) DownvotesInfo;
        mapping(uint8 => uint256) ReportsInfo;
        mapping(uint8 => uint256) CollectsInfo;
        mapping(uint8 => uint256) MirrorsInfo;
    }
}
