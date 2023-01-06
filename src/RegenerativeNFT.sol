// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { OwnableUpgradeable } from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC3525SlotEnumerableUpgradeable } from "erc-3525/contracts/ERC3525SlotEnumerableUpgradeable.sol";

import { IRNFT } from "./interfaces/IRNFT.sol";
import { IRLogic } from "./interfaces/IRLogic.sol";

import { TokenLibrary } from "./libraries/TokenLibrary.sol";
import { SlotLibrary } from "./libraries/SlotLibrary.sol";

contract RegenerativeNFT is
    IRNFT,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ERC3525SlotEnumerableUpgradeable
{
    using TokenLibrary for TokenLibrary.TimeData;
    using SlotLibrary for SlotLibrary.AssetData;

    uint256 internal constant APR = 30;
    uint256 constant public MATURITY = 600;

    mapping(address => uint256) private _slotOwner;
    mapping(uint256 => TokenLibrary.TimeData) private _allTimeData;
    mapping(uint256 => SlotLibrary.AssetData) private _allAssetData;

    address public logic;

    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _metadataDescriptor
    ) external initializer {
        __ERC3525_init(_name, _symbol, _decimals);
        __Ownable_init();
        _setMetadataDescriptor(_metadataDescriptor);
    }

    function setLogic(address _logic) external onlyOwner {
        logic = _logic;
    }

    
    /* ==================== Modifier ==================== */

    modifier onlyLogic() {
        if (_msgSender() != logic) revert NotLogic();
        _;
    }

    /* ==================== DEMO USE ONLY ==================== */

    function reset(address _owner) external onlyLogic {
        uint256 slot = slotByOwner(_owner);

        _allAssetData[slot].reset();
        uint256 length = tokenSupplyInSlot(slot);
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenInSlotByIndex(slot, 0);
            _burn(tokenId);
            _allTimeData[tokenId].burn();
        }
    }
    
    /* ==================== SLOT ==================== */

    function slotByOwner(address _owner) public view returns (uint256) {
        uint256 slot = _slotOwner[_owner];
        if (slot == 0) revert InvalidSlot();
        return slot;
    }

    function getAssetSnapshot(uint256 _slot)
        external
        view
        returns (SlotLibrary.AssetData memory)
    {
        SlotLibrary.AssetData memory assetData = _allAssetData[_slot];
        if (assetData.originator == address(0)) revert InvalidSlot();
        return assetData;
    }

    function createSlot(
        address _owner,
        string memory _category,
        string memory _rwaName,
        uint256 _rwaValue
    ) external onlyLogic returns (uint256) {
        uint256 slot = _slotOwner[_owner];

        if (slot == 0) {
            slot = slotCount() + 1;
            _createSlot(slot);
            _slotOwner[_owner] = slot;
        }

        _allAssetData[slot].createSlot(
            _owner,
            _category,
            _rwaName,
            _rwaValue
        );

        return slot;
    }

    /* ==================== TOKEN ==================== */

    function getTimeSnapshot(uint256 _tokenId)
        external
        view
        returns (TokenLibrary.TimeData memory)
    {
        TokenLibrary.TimeData memory timeData = _allTimeData[_tokenId];
        if (timeData.mintTime == 0) revert InvalidToken();
        return timeData;
    }

    function mint(address _minter, uint256 _value)
        external
        onlyLogic
        returns (uint256)
    {
        uint256 slot = slotByOwner(_minter);
        _allAssetData[slot].mint(_value);
        uint256 tokenId = _mint(_minter, slot, _value);
        _allTimeData[tokenId].mint();
        return tokenId;
    }

    function split(
        address _owner,
        uint256 _tokenId,
        uint256 _value
    ) external onlyLogic returns (uint256) {
        if (!_isApprovedOrOwner(_owner, _tokenId)) revert NotOwnerNorApproved();
        uint256 splittedTokenId = transferFrom(_tokenId, _owner, _value);
        _allTimeData[splittedTokenId].split(_allTimeData[_tokenId]);
        return splittedTokenId;
    }

    function merge(
        address _minter,
        uint256 _sourceId,
        uint256 _targetId
    ) external onlyLogic returns (uint256) {
        if (!(_isApprovedOrOwner(_minter, _sourceId) &&
                _isApprovedOrOwner(_minter, _targetId))) revert NotOwnerNorApproved();
        uint256 value = balanceOf(_sourceId);
        transferFrom(_sourceId, _targetId, value);
        _allTimeData[_targetId].merge(_allTimeData[_sourceId]);
        return value;
    }

    function redeem(address _owner, uint256 _tokenId)
        external
        onlyLogic
        returns (uint256, uint256)
    {
        if (!_isApprovedOrOwner(_owner, _tokenId)) revert NotOwnerNorApproved();
        TokenLibrary.TimeData storage timeData = _allTimeData[_tokenId];
        if (timeData.mintTime + MATURITY > block.timestamp)
            revert NotRedeemable();

        uint256 principal = balanceOf(_tokenId);
        uint256 interest = timeData.redeem(principal, APR);
        _burn(_tokenId);
        uint256 slot = slotByOwner(_owner);
        _allAssetData[slot].redeem(principal);
        return (principal, interest);
    }

    function claim(uint256 _tokenId)
        external
        onlyLogic
        returns (uint256, uint256)
    {
        uint256 principal = balanceOf(_tokenId);
        uint256 interest = _allTimeData[_tokenId].claim(principal, APR);
        return (principal, interest);
    }

    /* ==================== OVERRIDE ==================== */

    function _beforeValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) internal virtual override {
        if (fromTokenId_ == toTokenId_ && from_ != to_) {
            // transfer token to to_
            IRLogic(logic).beforeTransfer(
                fromTokenId_,
                IRLogic.Operation.Transfer
            );
        } else if (from_ == to_ && balanceOf(toTokenId_) != 0) {
            // merge
            IRLogic(logic).beforeTransfer(
                fromTokenId_,
                IRLogic.Operation.Merge
            );
        }
        
        slot_;
        value_;
    }

    function _afterValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) internal virtual override {
        if (from_ != address(0) && to_ != address(0) && balanceOf(fromTokenId_) == 0) {
            _burn(fromTokenId_);
        }

        super._afterValueTransfer(from_, to_, fromTokenId_, toTokenId_, slot_, value_);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override
        onlyOwner
    {}
}
