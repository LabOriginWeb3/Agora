// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {ICollectNFT} from './ICollectNFT.sol';
import {IERC721} from './IERC721.sol';
import {IAgoraHub} from './IAgoraHub.sol';
import {Errors} from './Errors.sol';
import {Events} from './Events.sol';
import {AgoraNFTBase} from './AgoraNFTBase.sol';
import {ERC721Enumerable} from './ERC721Enumerable.sol';

/**
 * @title CollectNFT
 * @author Agora Protocol
 *
 * @notice This is the NFT contract that is minted upon collecting a given publication. It is cloned upon
 * the first collect for a given publication, and the token URI points to the original publication's contentURI.
 */
contract CollectNFT is AgoraNFTBase, ICollectNFT {
    address public HUB;

    uint256 internal _profileId;
    uint256 internal _pubId;
    uint256 internal _tokenIdCounter;

    bool private _initialized;

    uint256 internal _royaltyBasisPoints;

    bytes4 internal constant INTERFACE_ID_ERC2981 = 0x2a55205a;
    uint16 internal constant BASIS_POINTS = 10000;

    constructor() {
        _initialized = false;
    }

    function initialize(
        uint256 profileId,
        uint256 pubId,
        address hub,
        string calldata name,
        string calldata symbol
    ) external override {
        if (_initialized) revert Errors.Initialized();
        _initialized = true;
        _royaltyBasisPoints = 1000; // 10% of royalties
        _profileId = profileId;
        HUB = hub;
        _pubId = pubId;
        super._initialize(name, symbol);
        emit Events.CollectNFTInitialized(profileId, pubId, block.timestamp);
    }

    function mint(address to) external override returns (uint256) {
        if (msg.sender != HUB) revert Errors.NotHub();
        unchecked {
            uint256 tokenId = ++_tokenIdCounter;
            _mint(to, tokenId);
            return tokenId;
        }
    }

    function getSourcePublicationPointer() external view override returns (uint256, uint256) {
        return (_profileId, _pubId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert Errors.TokenDoesNotExist();
        return IAgoraHub(HUB).getContentURI(_profileId, _pubId);
    }

    /**
     * @notice Changes the royalty percentage for secondary sales. Can only be called publication's
     *         profile owner.
     *
     * @param royaltyBasisPoints The royalty percentage meassured in basis points. Each basis point
     *                           represents 0.01%.
     */
    function setRoyalty(uint256 royaltyBasisPoints) external {
        if (IERC721(HUB).ownerOf(_profileId) == msg.sender) {
            if (royaltyBasisPoints > BASIS_POINTS) {
                revert Errors.InvalidParameter();
            } else {
                _royaltyBasisPoints = royaltyBasisPoints;
            }
        } else {
            revert Errors.NotProfileOwner();
        }
    }

    /**
     * @notice Called with the sale price to determine how much royalty
     *         is owed and to whom.
     *
     * @param tokenId The token ID of the NFT queried for royalty information.
     * @param salePrice The sale price of the NFT specified.
     * @return A tuple with the address who should receive the royalties and the royalty
     * payment amount for the given sale price.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address, uint256)
    {
        return (IERC721(HUB).ownerOf(_profileId), (salePrice * _royaltyBasisPoints) / BASIS_POINTS);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable)
        returns (bool)
    {
        return interfaceId == INTERFACE_ID_ERC2981 || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Upon transfers, we emit the transfer event in the hub.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId);
        IAgoraHub(HUB).emitCollectNFTTransferEvent(_profileId, _pubId, tokenId, from, to);
    }
}
