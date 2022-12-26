// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRLogic {
    error CannotMintZeroValue();
    error InsufficientBalance();
    error NotERC3525();
    error UnderMinimumValue();

    enum Operation {
        Claim,
        Merge,
        Split,
        Transfer
    }

    event Claim(address indexed _to, Operation indexed _operation, uint256[] _tokenIds, uint256[] _values, uint256[] _balances);
    event Redeem(address indexed _to, uint256[] _tokenIds, uint256[] _principals, uint256[] _interests);
    event Merge(address indexed _owner, uint256 _tokenId, uint256 _value, uint256[] _sourceTokenIds, uint256[] _values);
    event Split(address indexed _owner, uint256 _fromTokenId, uint256 _value, uint256[] _toTokenIds, uint256[] _splitUnits);
    event Mint(address indexed _owner, uint256 _tokenId, uint256 _value);
    event SlotValueChanged(uint256 indexed _slot, uint256 _oldValue, uint256 _newValue);
    
    /* ==================== DEMO USE ONLY ==================== */

    /**
     * @notice Owner withdraws test usdc
     */
    function withdraw() external;

    /**
     * @notice Slot owner resets all slot data and token data
     */
    function reset() external;
    
    /* ==================== SLOT ==================== */
    
    /**
     * @notice Create a slot and save the asset data
     * @param _category The RWA category
     * @param _rwaName The name of RWA
     * @param _rwaValue The RWA value priced by USDC
     */
    function createSlot(
        string memory _category,
        string memory _rwaName,
        uint256 _rwaValue
    ) external;
    
    /* ==================== TOKEN ==================== */

    /**
     * @notice Get all tokens owned by the owner
     * @param _owner The owner
     * @return The tokens that owner has
     */
    function getTokensByOwner(address _owner) external view returns (uint256[] memory);

    /**
     * @notice Mint a ERC-3525 NFT for the given slot with value
     * @param _value The value that minter is desired to mint
     */
    function mint(uint256 _value) external;

    /**
     * @notice Merge two tokens into one token
     * @param _sourceId The token is about to be merged
     * @param _targetId The token is about to merge
     */
    function merge(uint256 _sourceId, uint256 _targetId) external;

    /**
     * @notice Merge multiple tokens into one token
     * @param _sourceIds The tokens are about to be merged
     * @param _targetId The token is about to merge
     */
    function merge(uint256[] memory _sourceIds, uint256 _targetId) external;

    /**
     * @notice Split one token to two tokens
     * @param _tokenId The token is about to split
     * @param _value The value is splitted into new token
     */
    function split(uint256 _tokenId, uint256 _value) external;

    /**
     * @notice Split one token to multiple tokens
     * @param _tokenId The token is about to split
     * @param _values The values are splitted into new tokens
     */
    function split(uint256 _tokenId, uint256[] memory _values) external;

    /**
     * @notice Claim the interest of msg.sender
     */
    function claim() external;

    /**
     * @notice Redeem one token
     * @param _tokenId The token is about to redeem
     */
    function redeem(uint256 _tokenId) external;

    /**
     * @notice Redeem multiple tokens at once
     * @param _tokenIds The tokens are about to redeem
     */
    function redeem(uint256[] memory _tokenIds) external;

    /**
     * @notice this function will be triggered when the token or value of 
     *   ERC-3525 is transfered, it will claim the interest
     * @param _tokenId The token is about to transfer
     * @param _operation The operation of the tranfser(Merge / Transfer)
     */
    function beforeTransfer(uint256 _tokenId, Operation _operation) external;
}