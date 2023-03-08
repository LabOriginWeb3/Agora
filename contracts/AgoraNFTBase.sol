// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IAgoraNFTBase} from './IAgoraNFTBase.sol';
import {Errors} from './Errors.sol';
// import {DataTypes} from './DataTypes.sol';
import {Events} from './Events.sol';
import {ERC721Time} from './ERC721Time.sol';
import {ERC721Enumerable} from './ERC721Enumerable.sol';

/**
 * @title AgoraNFTBase
 * @author Agora Protocol
 *
 * @notice This is an abstract base contract to be inherited by other Agora Protocol NFTs, it includes
 * the slightly modified ERC721Enumerable, which itself inherits from the ERC721Time-- which adds an
 * internal operator approval setter, stores the mint timestamp for each token, and replaces the
 * constructor with an initializer.
 */
abstract contract AgoraNFTBase is ERC721Enumerable, IAgoraNFTBase {

    /**
     * @notice Initializer sets the name, symbol and the cached domain separator.
     *
     * NOTE: Inheritor contracts *must* call this function to initialize the name & symbol in the
     * inherited ERC721 contract.
     *
     * @param name The name to set in the ERC721 contract.
     * @param symbol The symbol to set in the ERC721 contract.
     */
    function _initialize(string calldata name, string calldata symbol) internal {
        ERC721Time.__ERC721_Init(name, symbol);

        emit Events.BaseInitialized(name, symbol, block.timestamp);
    }

    /// @inheritdoc IAgoraNFTBase
    function burn(uint256 tokenId) public virtual override {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert Errors.NotOwnerOrApproved();
        _burn(tokenId);
    }

}
