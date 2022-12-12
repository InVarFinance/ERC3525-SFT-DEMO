// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { TestERC20 } from "../src/TestERC20.sol";
import { RegenerativeNFT } from "../src/RegenerativeNFT.sol";
import { RegenerativeLogic } from "../src/RegenerativeLogic.sol";
import { RegenerativeMetadataDescriptor } from "../src/RegenerativeMetadataDescriptor.sol";

import { IRNFT } from "../src/interfaces/IRNFT.sol";
import { IRLogic } from "../src/interfaces/IRLogic.sol";

import { SlotLibrary } from "../src/libraries/SlotLibrary.sol";

contract RegenerativeTest is Test {

    TestERC20 erc20;
    RegenerativeNFT nft;
    RegenerativeLogic logic;
    RegenerativeMetadataDescriptor metadataDescriptor;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant internal CLAIM_AMOUNT = 100 * 1e6 wei;

    function setUp() public {
        metadataDescriptor = new RegenerativeMetadataDescriptor();
        erc20 = new TestERC20("Test USDC", "TUSD", 6);
        nft = new RegenerativeNFT();
        nft.initialize("RWANFT", "RNFT", uint8(erc20.decimals()), address(metadataDescriptor));
        logic = new RegenerativeLogic();
        nft.setLogic(address(logic));
        logic.initialize(nft, erc20);
        erc20.transfer(address(logic), 5_000 * 1e6);
    }

    function testClaimERC20() public {
        uint256 beforeClaim = erc20.balanceOf(alice);
        vm.prank(alice);
        erc20.claim();
        uint256 afterClaim = erc20.balanceOf(alice);
        assertEq(afterClaim - beforeClaim, CLAIM_AMOUNT);
    }

    function test_RevertClaimERC20WithAlreadyClaimed() public {
        vm.startPrank(alice);
        erc20.claim();
        vm.expectRevert(TestERC20.AlreadyClaimed.selector);
        erc20.claim();
        vm.stopPrank();
    }

    function testCreateSlot() public {
        vm.prank(alice);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        uint256 slot = nft.slotByOwner(alice);
        assertEq(slot, 1);
    }

    function test_RevertCreateSlotWithInvalidSlot() public {
        vm.expectRevert(IRNFT.InvalidSlot.selector);
        nft.slotByOwner(alice);
    }

    function testMint() public {
        vm.startPrank(alice);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        logic.mint(10 * 1e6);
        vm.stopPrank();
        uint256 balance = nft.balanceOf(alice);
        assertEq(balance, 1);
    }

    function test_RevertMintWithUnderMinimumValue() public {
        vm.startPrank(alice);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        vm.expectRevert(IRLogic.UnderMinimumValue.selector);
        logic.mint(0.1 * 1e6);
        vm.stopPrank();
    }

    function test_RevertMintWithExceedMintableValue() public {
        vm.startPrank(alice);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        vm.expectRevert(SlotLibrary.ExceedMintableValue.selector);
        logic.mint(60 * 1e6);
        vm.stopPrank();
    }

    function testMerge() public {
        uint256[] memory sourceIds = new uint256[](2);
        sourceIds[0] = 2;
        sourceIds[1] = 3;

        vm.startPrank(alice);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        logic.mint(10 * 1e6);
        uint256 beforeMerge = nft.balanceOf(1);
        logic.mint(20 * 1e6);
        logic.mint(20 * 1e6);
        nft.setApprovalForAll(address(logic), true);
        logic.merge(sourceIds, 1);
        vm.stopPrank();
        uint256 afterMerge = nft.balanceOf(1);
        assertEq(afterMerge - beforeMerge, 40 * 1e6);
    }

    function testMergeWithClaim() public {
        uint256[] memory sourceIds = new uint256[](2);
        sourceIds[0] = 2;
        sourceIds[1] = 3;

        vm.startPrank(alice);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        logic.mint(10 * 1e6);
        logic.mint(20 * 1e6);
        logic.mint(20 * 1e6);
        skip(1_000);
        nft.setApprovalForAll(address(logic), true);
        logic.merge(sourceIds, 1);
        vm.stopPrank();
        uint256 afterMerge = erc20.balanceOf(alice);
        assertTrue(afterMerge > 50 * 1e6);
    }

    function test_RevertMergeWithNotOwnerNorApproved() public {
        uint256[] memory sourceIds = new uint256[](2);
        sourceIds[0] = 2;
        sourceIds[1] = 3;

        vm.startPrank(alice);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        logic.mint(10 * 1e6);
        logic.mint(20 * 1e6);
        logic.mint(20 * 1e6);
        nft.setApprovalForAll(address(logic), true);
        changePrank(bob);
        vm.expectRevert(IRNFT.NotOwnerNorApproved.selector);
        logic.merge(sourceIds, 1);
        vm.stopPrank();
    }

    function testSplit() public {
        uint256[] memory values = new uint256[](2);
        values[0] = 20 * 1e6;
        values[1] = 20 * 1e6;

        vm.startPrank(alice);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        logic.mint(50 * 1e6);
        nft.setApprovalForAll(address(logic), true);
        logic.split(1, values);
        vm.stopPrank();
        uint256 balance = nft.balanceOf(alice);
        assertEq(balance, 3);
    }

    function test_RevertSplitWithNotOwnerNorApproved() public {
        uint256[] memory values = new uint256[](2);
        values[0] = 20 * 1e6;
        values[1] = 20 * 1e6;

        vm.startPrank(alice);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        logic.mint(50 * 1e6);
        changePrank(bob);
        vm.expectRevert(IRNFT.NotOwnerNorApproved.selector);
        logic.split(1, values);
        vm.stopPrank();
    }

    function testClaim() public {
        vm.startPrank(alice);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        logic.mint(50 * 1e6);
        skip(1_000);
        logic.claim();
        vm.stopPrank();
        uint256 balance = erc20.balanceOf(alice);
        assertTrue(balance > 50 * 1e6);
    }

    function testRedeem() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        vm.startPrank(alice);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        logic.mint(10 * 1e6);
        logic.mint(20 * 1e6);
        skip(600);
        nft.setApprovalForAll(address(logic), true);
        logic.redeem(tokenIds);
        vm.stopPrank();
        uint256 balance = nft.balanceOf(alice);
        assertEq(balance, 0);
    }

    function test_RevertRedeemWithNotOwnerNorApproved() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        vm.startPrank(alice);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        logic.mint(10 * 1e6);
        logic.mint(20 * 1e6);
        skip(600);
        nft.setApprovalForAll(address(logic), true);
        changePrank(bob);
        vm.expectRevert(IRNFT.NotOwnerNorApproved.selector);
        logic.redeem(tokenIds);
        vm.stopPrank();
    }

    function testReset() public {
        vm.startPrank(alice);
        erc20.claim();
        erc20.approve(address(logic), UINT256_MAX);
        logic.createSlot("Real Estate", "Mock RWA", 50 * 1e6);
        logic.mint(10 * 1e6);
        logic.reset();
        vm.stopPrank();

        vm.expectRevert(IRNFT.InvalidSlot.selector);
        nft.getAssetSnapshot(1);
        vm.expectRevert(IRNFT.InvalidToken.selector);
        nft.getTimeSnapshot(1);
        vm.expectRevert("ERC3525: invalid token ID");
        nft.ownerOf(1);
        uint256 slot = nft.slotByOwner(alice);
        assertEq(slot, 1);
    }
}