// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { OwnableUpgradeable } from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC3525SlotEnumerableUpgradeable } from "./ERC3525/ERC3525SlotEnumerableUpgradeable.sol";

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
    uint256 constant MATURITY = 600;

    mapping(address => uint256) private _slotOwner;
    mapping(uint256 => TokenLibrary.TimeData) private _allTimeData;
    mapping(address => SlotLibrary.AssetData) private _allAssetData;

    string private baseURI;
    address public logic;

    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        string memory _baseuri
    ) external initializer {
        __ERC3525_init(_name, _symbol, _decimals);
        __Ownable_init();
        baseURI = _baseuri;
    }

    function setBaseURI(string memory _baseuri) external onlyOwner {
        baseURI = _baseuri;
    }

    function setLogic(address _logic) external onlyOwner {
        logic = _logic;
    }

    /* ==================== Modifier ==================== */

    modifier onlyLogic() {
        if (_msgSender() != logic) revert NotLogic();
        _;
    }

    /* ==================== SLOT ==================== */

    function slotByOwner(address _owner) public view returns (uint256) {
        uint256 slot = _slotOwner[_owner];
        if (slot == 0) revert InvalidSlot();
        return slot;
    }

    function getAssetSnapshot(address _owner)
        external
        view
        returns (SlotLibrary.AssetData memory)
    {
        SlotLibrary.AssetData memory assetData = _allAssetData[_owner];
        if (assetData.originator != _owner) revert InvalidSlot();
        return assetData;
    }

    function createSlot(
        address _owner,
        string memory _category,
        string memory _rwaName,
        uint256 _rwaValue
    ) external onlyLogic returns (uint256) {
        uint256 slot = _slotOwner[_owner];

        _allAssetData[_owner].createSlot(
            _owner,
            _category,
            _rwaName,
            _rwaValue
        );

        if (slot == 0) {
            slot = slotCount() + 1;
            _createSlot(slot);
            _slotOwner[_owner] = slot;
        }

        return slot;
    }

    /* ==================== TOKEN ==================== */

    function getTimeSnapshot(uint256 tokenId_)
        external
        view
        returns (TokenLibrary.TimeData memory)
    {
        TokenLibrary.TimeData memory timeData = _allTimeData[tokenId_];
        if (timeData.mintTime == 0) revert InvalidToken();
        return timeData;
    }

    function mint(address _minter, uint256 _value)
        external
        onlyLogic
        returns (uint256)
    {
        uint256 slot = slotByOwner(_minter);
        _allAssetData[_minter].mint(_value);
        uint256 tokenId = _mint(_minter, slot, _value);
        _allTimeData[tokenId].mint();
        return tokenId;
    }

    function split(
        address owner_,
        uint256 tokenId_,
        uint256 value_
    ) external onlyLogic returns (uint256) {
        if (!_isApprovedOrOwner(owner_, tokenId_)) revert NotOwnerNorApproved();
        uint256 splittedTokenId = transferFrom(tokenId_, owner_, value_);
        _allTimeData[splittedTokenId].split(_allTimeData[tokenId_]);
        return splittedTokenId;
    }

    function merge(
        address _minter,
        uint256 sourceId_,
        uint256 targetId_
    ) external onlyLogic returns (uint256) {
        if (!(_isApprovedOrOwner(_minter, sourceId_) &&
                _isApprovedOrOwner(_minter, targetId_))) revert NotOwnerNorApproved();
        uint256 value = balanceOf(sourceId_);
        transferFrom(sourceId_, targetId_, value);
        _allTimeData[targetId_].merge(_allTimeData[sourceId_]);
        _burn(sourceId_);
        return value;
    }

    function redeem(address _owner, uint256 _tokenId)
        external
        onlyLogic
        returns (uint256, uint256)
    {
        if (!_isApprovedOrOwner(_msgSender(), _tokenId)) revert NotOwnerNorApproved();
        TokenLibrary.TimeData storage timeData = _allTimeData[_tokenId];
        if (timeData.mintTime + MATURITY > block.timestamp)
            revert NotRedeemable();

        uint256 principal = balanceOf(_tokenId);
        uint256 interest = timeData.redeem(principal, APR);
        _burn(_tokenId);
        _allAssetData[_owner].redeem(principal);
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

    function reset(address _owner) external onlyLogic {
        uint256 slot = slotByOwner(_owner);

        _allAssetData[_owner].reset();
        uint256 length = tokenSupplyInSlot(slot);
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenInSlotByIndex(slot, i);
            _burn(tokenId);
            _allTimeData[tokenId].burn();
        }
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

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override
        onlyOwner
    {}
}
