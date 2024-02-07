// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployNftMarketplace} from "../../script/DeployNftMarketplace.s.sol";
import {NFTMarketplace} from "../../src/NFTMarketplace.sol";
import {MocksTransferFailed} from "../mocks/MocksTransferFailed.sol";

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

    function test_CreateToken_UpdatesTotalNfts() public TokenCreated {
        NFTMarketplace.MarketItem[] memory marketItem = nftMarketplace.getAllNFTs();
        assertEq(marketItem[0].seller, seller1);
    }

    //////////////////////////////////////////////////////////
    /////////////////  Execute Sale Tests  ///////////////////
    //////////////////////////////////////////////////////////

    modifier TokenCreated() {
        vm.startPrank(seller1);
        nftMarketplace.createToken{value: LISTING_PRICE}(TOKEN_URI_1, NFT_PRICE);
        vm.stopPrank();
        _;
    }

    function test_RevertsIf_executeSaleWith_IncorrectBuyingPrice() public TokenCreated {
        vm.startPrank(seller2);
        vm.expectRevert(NFTMarketplace.NFTMarketplace__Incorrect_BuyingPrice.selector);
        nftMarketplace.executeSale(0);
        vm.stopPrank();
    }

    function test_executeSale() public TokenCreated {
        vm.startPrank(seller2);

        NFTMarketplace.MarketItem memory marketItem = nftMarketplace.getItemForTokenId(0);
        uint256 price = marketItem.price;

        nftMarketplace.executeSale{value: price}(0);

        vm.stopPrank();
    }

    modifier TokenCreateAnd_SaleExecuted() {
        vm.startPrank(seller1);
        nftMarketplace.createToken{value: LISTING_PRICE}(TOKEN_URI_1, NFT_PRICE);
        vm.stopPrank();

        vm.startPrank(seller2);

        NFTMarketplace.MarketItem memory marketItem = nftMarketplace.getItemForTokenId(0);
        uint256 price = marketItem.price;

        nftMarketplace.executeSale{value: price}(0);

        vm.stopPrank();
        _;
    }

    function test_executeSale_UpdatesSeller() public TokenCreateAnd_SaleExecuted {
        NFTMarketplace.MarketItem memory marketItem = nftMarketplace.getItemForTokenId(0);
        assertEq(marketItem.seller, seller2);
    }

    function test_executeSale_UpdatesItemsSold() public TokenCreateAnd_SaleExecuted {
        uint256 itemsSold = nftMarketplace.getItemsSold();
        assertEq(itemsSold, 1);
    }

    function test_executeSale_UpdatesPreviousSellerBalance() public TokenCreated {
        uint256 seller1PrevBalance = address(seller1).balance;
        vm.startPrank(seller2);

        NFTMarketplace.MarketItem memory marketItem = nftMarketplace.getItemForTokenId(0);
        uint256 price = marketItem.price;

        nftMarketplace.executeSale{value: price}(0);

        vm.stopPrank();

        uint256 seller1CurrentBalance = address(seller1).balance;

        assertEq(seller1CurrentBalance, seller1PrevBalance + marketItem.price);
    }

    function test_executeSale_UpdatesMarketplaceOwnerBalance() public TokenCreated {
        uint256 ownerBalanceBefore = address(msg.sender).balance;

        vm.startPrank(seller2);

        NFTMarketplace.MarketItem memory marketItem = nftMarketplace.getItemForTokenId(0);
        uint256 price = marketItem.price;

        nftMarketplace.executeSale{value: price}(0);

        vm.stopPrank();

        uint256 ownerBalanceAfter = address(msg.sender).balance;

        assertEq(ownerBalanceAfter, ownerBalanceBefore + LISTING_PRICE);
    }

    function test_RevertsIf_ItemAlreadySold() public TokenCreateAnd_SaleExecuted {
        vm.startPrank(seller2);

        NFTMarketplace.MarketItem memory marketItem = nftMarketplace.getItemForTokenId(0);
        uint256 price = marketItem.price;

        vm.expectRevert(NFTMarketplace.NFTMarketplace__Item_NotForSale.selector);
        nftMarketplace.executeSale{value: price}(0);

        vm.stopPrank();
    }

    function test_RevertsIf_TransferingAmountTo_SellerFailed() public {
        MocksTransferFailed mockTransferFailed = new MocksTransferFailed();
        vm.deal(address(mockTransferFailed), STARTING_BALANCE);

        vm.startPrank(address(mockTransferFailed));
        nftMarketplace.createToken{value: LISTING_PRICE}(TOKEN_URI_1, NFT_PRICE);
        vm.stopPrank();

        vm.startPrank(seller2);

        NFTMarketplace.MarketItem memory marketItem = nftMarketplace.getItemForTokenId(0);
        uint256 price = marketItem.price;

        vm.expectRevert(NFTMarketplace.NFTMarketplace__TransferFailed.selector);
        nftMarketplace.executeSale{value: price}(0);

        vm.stopPrank();
    }

    function test_RevertsIf_TransferingAmountTo_MarketOwnerFailed() public {
        MocksTransferFailed mockTransferFailed = new MocksTransferFailed();
        vm.deal(address(mockTransferFailed), STARTING_BALANCE);

        vm.startPrank(address(mockTransferFailed));
        NFTMarketplace mockNftMarketPlace = new NFTMarketplace();
        vm.stopPrank();

        vm.startPrank(seller1);
        mockNftMarketPlace.createToken{value: LISTING_PRICE}(TOKEN_URI_1, NFT_PRICE);
        vm.stopPrank();

        vm.startPrank(seller2);

        NFTMarketplace.MarketItem memory marketItem = mockNftMarketPlace.getItemForTokenId(0);
        uint256 price = marketItem.price;

        vm.expectRevert(NFTMarketplace.NFTMarketplace__TransferFailed.selector);
        mockNftMarketPlace.executeSale{value: price}(0);

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////////
    //////////////////////  Re-Sell Tests  ///////////////////
    //////////////////////////////////////////////////////////

    function test_RevertsIf_reSellNft_NotCalledByOwner() public TokenCreateAnd_SaleExecuted {
        vm.startPrank(seller1);
        vm.expectRevert(NFTMarketplace.NFTMarketplace__OnlyOwnerCan_ReSell.selector);
        nftMarketplace.reSellNft(0, 0.03 ether);
        vm.stopPrank();
    }

    function test_RevertsIf_reSellNft_IncorrectListingPrice() public TokenCreateAnd_SaleExecuted {
        vm.startPrank(seller2);
        vm.expectRevert(NFTMarketplace.NFTMarketplace__Incorrect_ListingPrice.selector);
        nftMarketplace.reSellNft{value: 0}(0, 0.03 ether);
        vm.stopPrank();
    }

    function test_RevertsIf_reSellNft_PriceIsZero() public TokenCreateAnd_SaleExecuted {
        vm.startPrank(seller2);
        vm.expectRevert(NFTMarketplace.NFTMarketplace__PriceCannot_BeZero.selector);
        nftMarketplace.reSellNft{value: LISTING_PRICE}(0, 0);
        vm.stopPrank();
    }

    function test_RevertsIf_reSellNft() public TokenCreateAnd_SaleExecuted {
        vm.startPrank(seller2);
        nftMarketplace.reSellNft{value: LISTING_PRICE}(0, 0.03 ether);
        vm.stopPrank();
    }

    function test_RevertsIf_reSellNft_UpdatesItemsSold() public TokenCreateAnd_SaleExecuted {
        vm.startPrank(seller2);
        nftMarketplace.reSellNft{value: LISTING_PRICE}(0, 0.03 ether);
        vm.stopPrank();

        uint256 itemsSold = nftMarketplace.getItemsSold();
        assertEq(itemsSold, 0);
    }

    //////////////////////////////////////////////////////////
    //////////////////  Multiple Token Tests  ////////////////
    //////////////////////////////////////////////////////////
    function test_CreateMultipleTokens() public {
        vm.startPrank(seller1);
        nftMarketplace.createToken{value: LISTING_PRICE}(TOKEN_URI_1, NFT_PRICE);
        nftMarketplace.createToken{value: LISTING_PRICE}(TOKEN_URI_2, 0.02 ether);
        vm.stopPrank();

        NFTMarketplace.MarketItem[] memory marketItems = nftMarketplace.getAllNFTs();
        assertEq(marketItems.length, 2);

        assertEq(marketItems[1].price, 0.02 ether);
    }
}
