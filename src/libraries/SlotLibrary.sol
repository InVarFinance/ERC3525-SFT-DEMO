// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SlotLibrary {
    error InsufficientBalance();
    error ExceedMintableValue();
    error ExceedUnits();
    error InvalidToken();
    error NotClaimable();
    error NotOriginator();

    struct AssetData {
        address originator;
        string category;
        string rwaName;
        uint256 rwaValue;
        uint256 mintableValue;
    }

    /**
     * @dev Create an asset data to store basic info
     * of the RWA
     */
    function createSlot(
        AssetData storage self,
        address originator,
        string memory category,
        string memory rwaName,
        uint256 rwaValue
    ) internal {
        self.originator = originator;
        self.category = category;
        self.rwaName = rwaName;
        self.rwaValue = rwaValue;
        self.mintableValue = rwaValue;
    }

    /**
     * @dev Clear the asset data
     */
    function reset(AssetData storage self) internal {
        delete self.originator;
        delete self.category;
        delete self.rwaName;
        delete self.rwaValue;
        delete self.mintableValue;
    }

    /**
     * @dev When user mints the ERC-3525 nft, it will reduce
     * the mintable value for the given asset
     */
    function mint(AssetData storage self, uint256 value) internal {
        if (self.mintableValue < value) revert ExceedMintableValue();
        self.mintableValue -= value;
    }

    /**
     * @dev The redemption will increase the mintable value for
     * the given asset
     */
    function redeem(AssetData storage self, uint256 value) internal {
        self.mintableValue += value;
    }
}
