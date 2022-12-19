//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC3525SlotEnumerableUpgradeable} from "erc-3525/contracts/extensions/IERC3525SlotEnumerableUpgradeable.sol";
import {IERC3525MetadataUpgradeable} from "erc-3525/contracts/extensions/IERC3525MetadataUpgradeable.sol";

import "../libraries/SlotLibrary.sol";
import "../libraries/TokenLibrary.sol";

interface IRNFT is IERC3525MetadataUpgradeable, IERC3525SlotEnumerableUpgradeable {
    error NotLogic();
    error NotOwnerNorApproved();
    error NotRedeemable();
    error InvalidSlot();
    error InvalidToken();

    /* ==================== DEMO USE ONLY ==================== */
    
    /**
     * @notice Reset the slot data and the token data
     * @param _owner The owner of the slot
     */
    function reset(address _owner) external;

    /* ==================== SLOT ==================== */

    /**
     * @notice Get the slot of owner
     * @param _owner The owner of the slot
     * @return The slot
     */
    function slotByOwner(address _owner) external view returns (uint256);

    /**
     * @notice Get the Snapshot of the asset
     * @param _slot The owner of the slot
     * @return The asset data for the given slot 
     */
    function getAssetSnapshot(uint256 _slot) external view returns (SlotLibrary.AssetData memory);

    /**
     * @notice create a slot of ERC-3525
     * @param _owner The owner of the slot
     * @param _category The RWA category
     * @param _rwaName The RWA name
     * @param _rwaValue The RWA tokenization value
     */
    function createSlot(address _owner, string memory _category, string memory _rwaName, uint256 _rwaValue) external returns (uint256);

    /* ==================== TOKEN ==================== */

    /**
     * @notice Get the snapshot of the time data
     * @param _tokenId The token of the time data
     * @return The time data for the given token
     */
    function getTimeSnapshot(uint256 _tokenId) external view returns (TokenLibrary.TimeData memory);

    /**
     * @notice Mint a token with the slot for the specific value
     * @param _minter The minter is to mint a ERC-3525
     * @param _value The value that minter is desired to mint
     * @return The minted tokenId
     */
    function mint(address _minter, uint256 _value) external returns (uint256);

    /**
     * @notice Split the token to two tokens
     * @param _owner The owner of tokens
     * @param _tokenId The token is to splitted
     * @param _value The value of new token
     * @return The splitted token
     */
    function split(address _owner, uint256 _tokenId, uint256 _value) external returns (uint256);

    /**
     * @notice Merge two tokens with the same slot into one token
     * @param _owner The owner of tokens
     * @param _sourceId The source token
     * @param _targetId The target token
     * @return The source token value
     */
    function merge(address _owner, uint256 _sourceId, uint256 _targetId) external returns (uint256);
    
    /**
     * @notice Redeem the principal with interest,
     *   and burn the redeemed token
     * @param _owner The token owner
     * @param _tokenId The token is about to redeem
     * @return The principal with the interest of the token
     */
    function redeem(address _owner, uint256 _tokenId) external returns (uint256, uint256);

    /**
     * @notice Calculate the claimable interest for the given token
     * @param _tokenId The token
     * @return The principal with the interest of the token
     */
    function claim(uint256 _tokenId) external returns (uint256, uint256);
}