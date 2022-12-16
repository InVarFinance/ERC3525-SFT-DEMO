// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IRNFT } from "./interfaces/IRNFT.sol";
import { SlotLibrary } from "./libraries/SlotLibrary.sol";
import { IERC3525MetadataDescriptor } from "erc-3525/contracts/periphery/interface/IERC3525MetadataDescriptor.sol";
import { Base64 } from "openzeppelin-contracts/utils/Base64.sol";
import { Strings } from "openzeppelin-contracts/utils/Strings.sol";

contract RegenerativeMetadataDescriptor is IERC3525MetadataDescriptor {
    using Strings for uint256;

    string IMAGE_URL = "https://ipfs.filebase.io/ipfs/QmbNg29bQpr4wC5qDoCzt8uBYKUc5U15uvuarvydLwsTMK";

    function constructContractURI() external view returns (string memory) {
        IRNFT irnft = IRNFT(msg.sender);
        return 
        string(
            abi.encodePacked(
            /* solhint-disable */
            'data:application/json;base64,',
            Base64.encode(
                abi.encodePacked(
                '{"name":"', 
                irnft.name(),
                '","description":"',
                _contractDescription(),
                '","image":"',
                _contractImage(),
                '","valueDecimals":"', 
                uint256(irnft.valueDecimals()).toString(),
                '"}'
                )
            )
            /* solhint-enable */
            )
        );
    }

    function constructSlotURI(uint256 slot_) external view returns (string memory) {
        return
            string(
                abi.encodePacked(
                /* solhint-disable */
                'data:application/json;base64,',
                Base64.encode(
                    abi.encodePacked(
                    '{"name":"', 
                    _slotName(slot_),
                    '","description":"',
                    _slotDescription(),
                    '","image":"',
                    IMAGE_URL,
                    '","properties":',
                    _slotProperties(slot_),
                    '}'
                    )
                )
                /* solhint-enable */
                )
            );
    }
    
    function constructTokenURI(uint256 tokenId_) external view returns (string memory) {
        return 
        string(
            abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(
                abi.encodePacked(
                /* solhint-disable */
                '{"name":"',
                _tokenName(tokenId_),
                '","description":"',
                _tokenDescription(),
                '","external_url":"https://app.invar.finance/sftdemo"'
                ',"image":"',
                IMAGE_URL,
                '","properties":',
                _tokenProperties(),
                "}"
                /* solhint-enable */
                )
            )
            )
        );
    }

    function _contractDescription() internal pure returns (string memory) {
        return "";
    }

    function _contractImage() internal pure returns (bytes memory) {
        return "";
    }

    function _slotDetail(uint256 slot_) private view returns (SlotLibrary.AssetData memory) {
        IRNFT irnft = IRNFT(msg.sender);
        return irnft.getAssetSnapshot(slot_);
    }

    function _slotName(uint256 slot_) internal view returns (string memory) {
        return _slotDetail(slot_).rwaName;
    }

    function _slotDescription() internal pure returns (string memory) {
        return "";
    }

    function _slotProperties(uint256 slot_) internal view returns (string memory) {
        return 
        string(
            /* solhint-disable */
            abi.encodePacked(
            "[",
                abi.encodePacked(
                '{"name":"category",',
                '"description":"The category of real world asset.",',
                '"value":"',
                    _slotDetail(slot_).category,
                '",',
                '"display_type":"string"},'
                ),
            "]"
            )
            /* solhint-enable */
        );
    }

    function _slotOf(uint256 tokenId_) private view returns (uint256) {
        IRNFT irnft = IRNFT(msg.sender);
        return irnft.slotOf(tokenId_);
    }

    function _tokenName(uint256 tokenId_) internal view returns (string memory) {
        // solhint-disable-next-line
        return 
        string(
            abi.encodePacked(
            _slotName(_slotOf(tokenId_)), 
            " #", tokenId_.toString()
            )
        );
    }

    function _tokenDescription() internal pure returns (string memory) {
        return "";
    }

    function _tokenImage() internal view returns (bytes memory) {
        return abi.encodePacked(IMAGE_URL);
    }

    function _tokenProperties() internal pure returns (string memory) {
        return 
        string(
            abi.encodePacked(
            /* solhint-disable */
            '{"Factory":',
                '"InVaria SFT Factory"',
                ',"Standards":',
                '"ERC-3525"',
                ',"NFT Type":',
                '"RWA Tokenization"'
            '}'
            /* solhint-enable */
            )
        );
    }
}