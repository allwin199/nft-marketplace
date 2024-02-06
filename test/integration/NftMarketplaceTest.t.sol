// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployNftMarketplace} from "../../script/DeployNftMarketplace.s.sol";
import {NFTMarketplace} from "../../src/NFTMarketplace.sol";

contract NftMarketplaceTest is Test {
    //////////////////////////////////////////////////////////
    ////////////////  Storage Variables  /////////////////////
    //////////////////////////////////////////////////////////

    NFTMarketplace nftMarketplace;
    uint256 private constant LISTING_PRICE = 0.01 ether;
    uint256 private constant NFT_PRICE = 0.01 ether;
    uint256 private constant STARTING_BALANCE = 100 ether;

    string private constant TOKEN_URI_1 = "ipfs://bafybeicnfpbzxjnotpuemferlm6xqfsurn77eqpv7d6ryu27kyhmmslc6u/";
    string private constant TOKEN_URI_2 = "ifps://QmWJW9tjnz4kvbeZfQ3zz3L5cJB6h9Nu1NAfxoJDPrjcS5";

    address private seller1 = makeAddr("seller1");
    address private seller2 = makeAddr("seller2");

    //////////////////////////////////////////////////////////
    //////////////////////   Events  /////////////////////////
    //////////////////////////////////////////////////////////
    event MarketItemCreated(
        uint256 indexed tokenId, address indexed owner, address indexed seller, uint256 price, bool sold
    );

    function setUp() external {
        DeployNftMarketplace deployer = new DeployNftMarketplace();
        nftMarketplace = deployer.run();

        vm.deal(seller1, STARTING_BALANCE);
        vm.deal(seller2, STARTING_BALANCE);
    }

    //////////////////////////////////////////////////////////
    ////////////////  Listing Price Tests  ///////////////////
    //////////////////////////////////////////////////////////

    function test_ListingPrice() public {
        uint256 listingPrice = nftMarketplace.getListingPrice();
        assertEq(listingPrice, LISTING_PRICE);
    }

    function test_RevertsIf_UpdateListing_NotCalledByOwner() public {
        vm.expectRevert(NFTMarketplace.NFTMarketplace__OnlyOwnerCan_UpdateListingPrice.selector);
        nftMarketplace.updateListingPrice(0);
    }

    function test_RevertsIf_UpdateListingPrice_IsZero() public {
        vm.startPrank(msg.sender);
        vm.expectRevert(NFTMarketplace.NFTMarketplace__PriceCannot_BeZero.selector);
        nftMarketplace.updateListingPrice(0);
        vm.stopPrank();
    }

    function test_UpdateListingPrice() public {
        vm.startPrank(msg.sender);
        uint256 newPrice = 0.02 ether;
        nftMarketplace.updateListingPrice(newPrice);
        vm.stopPrank();

        uint256 listingPrice = nftMarketplace.getListingPrice();
        assertEq(listingPrice, newPrice);
    }

    //////////////////////////////////////////////////////////
    /////////////////  Create Token Tests  ///////////////////
    //////////////////////////////////////////////////////////

    function test_RevertsIf_CreateTokenWith_ZeroPrice() public {
        vm.startPrank(seller1);
        vm.expectRevert(NFTMarketplace.NFTMarketplace__PriceCannot_BeZero.selector);
        nftMarketplace.createToken(TOKEN_URI_1, 0);
        vm.stopPrank();
    }

    function test_RevertsIf_CreateTokenWith_IncorrectListingPrice() public {
        vm.startPrank(seller1);
        vm.expectRevert(NFTMarketplace.NFTMarketplace__Incorrect_ListingPrice.selector);
        nftMarketplace.createToken(TOKEN_URI_1, NFT_PRICE);
        vm.stopPrank();
    }

    function test_CreateToken() public {
        vm.startPrank(seller1);
        nftMarketplace.createToken{value: LISTING_PRICE}(TOKEN_URI_1, NFT_PRICE);
        vm.stopPrank();
    }

    function test_CreateToken_UpdatesItem() public {
        vm.startPrank(seller1);
        nftMarketplace.createToken{value: LISTING_PRICE}(TOKEN_URI_1, NFT_PRICE);
        vm.stopPrank();

        NFTMarketplace.MarketItem memory nftItem = nftMarketplace.getItemForTokenId(0);

        assertEq(nftItem.price, NFT_PRICE);
    }

    function test_CreateToken_UpdatesTokenId() public {
        vm.startPrank(seller1);
        nftMarketplace.createToken{value: LISTING_PRICE}(TOKEN_URI_1, NFT_PRICE);
        vm.stopPrank();

        uint256 tokenId = nftMarketplace.getCurrentTokenId();
        assertEq(tokenId, 1);
    }

    function test_CreateToken_EmitsEvent() public {
        vm.startPrank(seller1);
        vm.expectEmit(true, true, true, false, address(nftMarketplace));
        emit MarketItemCreated(0, address(nftMarketplace), seller1, NFT_PRICE, false);
        nftMarketplace.createToken{value: LISTING_PRICE}(TOKEN_URI_1, NFT_PRICE);
        vm.stopPrank();
    }
}
