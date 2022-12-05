// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TokenLibrary {

    uint256 internal constant PERCENTAGE = 100;
    uint256 internal constant YEAR_IN_SECS = 31_536_000;

    struct TimeData {
        uint64 mintTime;
        uint64 claimTime;
    }

    /**
     * @dev Logic contract will store time data which is binding
     * token Id while user mints a ERC-3525 NFT
     */
    function mint(TimeData storage self) internal {
        self.mintTime = uint64(block.timestamp);
        self.claimTime = uint64(block.timestamp);
    }

    /**
     * @dev When user claim the interest, the claim time of time data
     * will be updated
     */
    function claim(TimeData storage self, uint256 value, uint256 apr) internal returns (uint256) {
        uint256 secs = block.timestamp - self.claimTime;
        uint256 interest = calculateClaimableInterest(value, secs, apr);
        self.claimTime = uint64(block.timestamp);
        return interest;
    }

    /**
     * @dev When user merge two tokens, the mint time will be
     * the later timestamp, and the bonus seconds will be accumulated.
     */
    function merge(TimeData storage self, TimeData storage source) internal {
        if (source.mintTime > self.mintTime) {
            self.mintTime = source.mintTime;
        }
        burn(source);
    }

    /**
     * @dev When user splits the token, the new token will inherit all
     * time data from orginal token
     */
    function split(TimeData storage self, TimeData memory source) internal {
        self.mintTime = source.mintTime;
        self.claimTime = source.claimTime;
    }

    /**
     * @dev Delete the time data
     */
    function burn(TimeData storage self) internal {
        delete self.mintTime;
        delete self.claimTime;
    }

    /**
     * @dev Redeem the principal with the interest of the token
     */
    function redeem(TimeData storage self, uint256 value, uint256 apr) internal returns (uint256) {
        uint256 secs = block.timestamp - self.claimTime;
        uint256 interest = calculateClaimableInterest(value, secs, apr);
        burn(self);
        return interest;
    }

    /**
     * @dev Calculate the claimable interest
     */
    function calculateClaimableInterest(
        uint256 value,
        uint256 secs,
        uint256 apr
    ) internal pure returns (uint256) {
        return
            (secs * apr * value) /
            (YEAR_IN_SECS * PERCENTAGE);
    }
}