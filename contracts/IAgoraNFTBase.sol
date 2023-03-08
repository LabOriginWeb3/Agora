// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {DataTypes} from './DataTypes.sol';

/**
 * @title IAgoraNFTBase
 * @author Agora Protocol
 *
 * @notice This is the interface for the AgoraNFTBase contract, from which all Agora NFTs inherit.
 * It is an expansion of a very slightly modified ERC721Enumerable contract, which allows expanded
 * meta-transaction functionality.
 */
interface IAgoraNFTBase {


    /**
     * @notice Burns an NFT, removing it from circulation and essentially destroying it. This function can only
     * be called by the NFT to burn's owner.
     *
     * @param tokenId The token ID of the token to burn.
     */
    function burn(uint256 tokenId) external;

}
