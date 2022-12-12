// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RegenerativeNFT} from "../src/RegenerativeNFT.sol";
import {RegenerativeLogic} from "../src/RegenerativeLogic.sol";
import {RegenerativeMetadataDescriptor} from "../src/RegenerativeMetadataDescriptor.sol";
import {TestERC20} from "../src/TestERC20.sol";

contract RegenerativeScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        TestERC20 erc20 = new TestERC20("Test USDC", "TUSD", 6);

        RegenerativeMetadataDescriptor metadataDescriptor = new RegenerativeMetadataDescriptor();
        
        RegenerativeNFT nft = new RegenerativeNFT();
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nft), abi.encodeWithSelector(RegenerativeNFT.initialize.selector, "RWANFT", "RNFT", erc20.decimals(), address(metadataDescriptor)));
        
        RegenerativeLogic logic = new RegenerativeLogic();
        ERC1967Proxy logicProxy = new ERC1967Proxy(address(logic), abi.encodeWithSelector(RegenerativeLogic.initialize.selector, nftProxy, erc20));
        
        address(nftProxy).call(abi.encodeWithSelector(RegenerativeNFT.setLogic.selector, address(logicProxy)));
        vm.stopBroadcast();
    }
}