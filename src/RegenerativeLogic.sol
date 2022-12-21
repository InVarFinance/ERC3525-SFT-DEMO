// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { OwnableUpgradeable } from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20 } from "openzeppelin-contracts/interfaces/IERC20.sol";
import { UUPSUpgradeable } from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IRNFT } from "./interfaces/IRNFT.sol";
import { IRLogic } from "./interfaces/IRLogic.sol";

contract RegenerativeLogic is
    IRLogic,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    uint256 constant MIN_MINT_VALUE = 1 * 1e6 wei;

    IRNFT irnft;
    IERC20 erc20;

    function initialize(IRNFT _irnft, IERC20 _currency) external initializer {
        __Ownable_init();
        irnft = _irnft;
        erc20 = _currency;
    }

    /* ==================== DEMO USE ONLY ==================== */

    function withdraw() external onlyOwner {
        if (erc20.balanceOf(address(this)) == 0) revert InsufficientBalance();
        erc20.transfer(_msgSender(), erc20.balanceOf(address(this)));
    }

    function reset() external {
        irnft.reset(_msgSender());
    }

    /* ==================== SLOT ==================== */

    function createSlot(
        string memory _category,
        string memory _rwaName,
        uint256 _rwaValue
    ) external {
        uint256 slot = irnft.createSlot(_msgSender(), _category, _rwaName, _rwaValue);
        emit SlotValueChanged(slot, 0, _rwaValue);
    }

    /* ==================== TOKEN ==================== */

    function getTokensByOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = irnft.balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = irnft.tokenOfOwnerByIndex(owner, i);
        }
        return tokenIds;
    }

    function mint(uint256 _value) external {
        address owner = _msgSender();
        if (MIN_MINT_VALUE > _value) revert UnderMinimumValue();
        uint256 tokenId = irnft.mint(owner, _value);
        erc20.transferFrom(owner, address(this), _value);
        emit Mint(owner, tokenId, _value);
    }

    /**
     * merge functions
     */
    function merge(uint256 sourceId_, uint256 targetId_) external {
        uint256[] memory sourceIds = new uint256[](1);
        sourceIds[0] = sourceId_;
        _merge(sourceIds, targetId_);
    }

    function merge(uint256[] memory sourceIds_, uint256 targetId_) external {
        _merge(sourceIds_, targetId_);
    }

    function _merge(uint256[] memory sourceIds_, uint256 targetId_) internal {
        address owner = _msgSender();
        // claim the interest of targetId
        claim(targetId_, Operation.Merge);
        uint256 length = sourceIds_.length;
        uint256[] memory values = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            values[i] = irnft.merge(owner, sourceIds_[i], targetId_);
        }

        emit Merge(owner, targetId_, irnft.balanceOf(targetId_), sourceIds_, values);
    }

    /**
     * split functions
     */
    function split(uint256 tokenId_, uint256 value_) external {
        uint256[] memory values = new uint256[](1);
        values[0] = value_;
        _split(tokenId_, values);
    }

    function split(uint256 tokenId_, uint256[] memory values_) external {
        _split(tokenId_, values_);
    }

    function _split(uint256 tokenId_, uint256[] memory values_) internal {
        address owner = _msgSender();
        claim(tokenId_, Operation.Split);
        uint256 length = values_.length;
        uint256[] memory splittedTokens = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            splittedTokens[i] = irnft.split(owner, tokenId_, values_[i]);
        }
        emit Split(owner, tokenId_, irnft.balanceOf(tokenId_), splittedTokens, values_);
    }

    /**
     *  claim functions
     */
    function claim(uint256 _tokenId, Operation _operation) internal {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        _claim(tokenIds, _operation);
    }

    function claim() external {
        uint256 slot = irnft.slotByOwner(_msgSender());
        uint256 length = irnft.tokenSupplyInSlot(slot);
        uint256[] memory tokenIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            tokenIds[i] = irnft.tokenInSlotByIndex(slot, i);
        }

        _claim(tokenIds, Operation.Claim);
    }

    function _claim(uint256[] memory _tokenIds, Operation _operation) internal {
        // msg.sender would be Regenerative NFT
        // merge & transfer will trigger before transferValue hook
        address owner = irnft.ownerOf(_tokenIds[0]);
        uint256 length = _tokenIds.length;
        uint256[] memory principals = new uint256[](length);
        uint256[] memory interests = new uint256[](length);
        uint256 balance;

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = _tokenIds[i];
            (uint256 principal, uint256 interest) = irnft.claim(tokenId);
            balance += interest;
            principals[i] = principal;
            interests[i] = interest;
        }

        erc20.transfer(owner, balance);

        emit Claim(owner, _operation, _tokenIds, principals, interests);
    }

    /**
     *  redeem functions
     */
    function redeem(uint256 _tokenId) external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;
        _redeem(tokenIds);
    }

    function redeem(uint256[] memory _tokenIds) external {
        _redeem(_tokenIds);
    }

    function _redeem(uint256[] memory _tokenIds) internal {
        address owner = _msgSender();
        uint256 length = _tokenIds.length;
        uint256[] memory tokens = new uint256[](length);
        uint256[] memory principals = new uint256[](length);
        uint256[] memory interests = new uint256[](length);
        uint256 balance;

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = _tokenIds[i];
            (uint256 principal, uint256 interest) = irnft.redeem(owner, tokenId);

            balance += principal + interest;
            tokens[i] = tokenId;
            principals[i] = principal;
            interests[i] = interest;
        }

        erc20.transfer(owner, balance);

        emit Redeem(owner, tokens, principals, interests);
    }

    function beforeTransfer(uint256 _tokenId, Operation _operation) external {
        if (_msgSender() != address(irnft)) revert NotERC3525();
        claim(_tokenId, _operation);
    }

    // override
    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override
        onlyOwner
    {}
}