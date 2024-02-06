// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

//////////////////////////////////////////////////////////
///////////////////////  Imports  ////////////////////////
//////////////////////////////////////////////////////////
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title NFT Marketplace
/// @author Prince Allwin
/// @notice Users can list their nft and other people can buy them.
contract NFTMarketplace is ERC721URIStorage {
    //////////////////////////////////////////////////////////
    ////////////////////  Custom Errors  /////////////////////
    //////////////////////////////////////////////////////////
    error NFTMarketplace__OnlyOwnerCan_UpdateListPrice();
    error NFTMarketplace__Incorrect_ListingPrice();
    error NFTMarketplace__PriceCannot_BeZero();
    error NFTMarketplace__TransferFailed();

    //////////////////////////////////////////////////////////
    ////////////////  Type Declarations  /////////////////////
    //////////////////////////////////////////////////////////
    struct MarketItem {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool sold;
    }

    //////////////////////////////////////////////////////////
    ///////////  Constant and Immutable Variables  ///////////
    //////////////////////////////////////////////////////////
    address payable private immutable i_owner;

    //////////////////////////////////////////////////////////
    ////////////////  Storage Variables  /////////////////////
    //////////////////////////////////////////////////////////
    uint256 private s_tokenId;
    uint256 private s_itemsSold;
    uint256 private s_listingPrice = 0.01 ether;

    mapping(uint256 tokenId => MarketItem) private s_idToMarketItem;

    //////////////////////////////////////////////////////////
    //////////////////////   Events  /////////////////////////
    //////////////////////////////////////////////////////////
    event MarketItemCreated(
        uint256 indexed tokenId, address indexed owner, address indexed seller, uint256 price, bool sold
    );
    event TokenListedSuccess(
        uint256 indexed tokenId, address indexed owner, address indexed seller, uint256 price, bool currentlyListed
    );

    //////////////////////////////////////////////////////////
    //////////////////////  Functions  ///////////////////////
    //////////////////////////////////////////////////////////

    constructor() ERC721("NFTMarketplace", "NFTM") {
        i_owner = payable(msg.sender);
    }

    //////////////////////////////////////////////////////////
    /////////////////  External Functions  ///////////////////
    //////////////////////////////////////////////////////////
    function createToken(string memory tokenURI, uint256 price) external payable returns (uint256) {
        if (price < 0) {
            revert NFTMarketplace__PriceCannot_BeZero();
        }

        if (msg.value != s_listingPrice) {
            revert NFTMarketplace__Incorrect_ListingPrice();
        }

        _mint(msg.sender, s_tokenId);
        _setTokenURI(s_tokenId, tokenURI);
        createMarketItem(s_tokenId, price);

        s_tokenId = s_tokenId + 1;

        return s_tokenId - 1;
    }

    function updateListPrice(uint256 newPrice) external {
        if (msg.sender != i_owner) {
            revert NFTMarketplace__OnlyOwnerCan_UpdateListPrice();
        }
        s_listingPrice = newPrice;
    }

    //////////////////////////////////////////////////////////
    //////////////////  Private Functions  ///////////////////
    //////////////////////////////////////////////////////////
    function createMarketItem(uint256 _tokenId, uint256 _price) private {
        s_idToMarketItem[_tokenId] = MarketItem({
            tokenId: _tokenId,
            owner: payable(address(this)),
            seller: payable(msg.sender),
            price: _price,
            sold: false
        });

        // right now msg.sender is the owner of the token
        // Inorder for market place to perform actions on  behalf of the user
        // user should transfer the token to the marketplace
        _transfer(msg.sender, address(this), _tokenId);
        // now marketplace owns this NFT

        emit MarketItemCreated(_tokenId, address(this), msg.sender, _price, false);
    }

    //////////////////////////////////////////////////////////
    //////////////////  Getter Functions  ////////////////////
    //////////////////////////////////////////////////////////
    function getListingPrice() external view returns (uint256) {
        return s_listingPrice;
    }

    function getLatestListedItem() external view returns (MarketItem memory) {
        return s_idToMarketItem[s_tokenId - 1];
    }

    function getItemForTokenId(uint256 tokenId) external view returns (MarketItem memory) {
        return s_idToMarketItem[tokenId];
    }

    function getCurrentTokenId() external view returns (uint256) {
        return s_tokenId;
    }

    // function createToken(string memory tokenURI, uint256 price) public payable returns (uint256) {
    //     if (msg.value != s_listingPrice) {
    //         revert NFTMarketplace__IncorrectPrice();
    //     }

    //     if (price == 0) {
    //         revert NFTMarketplace__PriceCannot_BeZero();
    //     }

    //     _safeMint(msg.sender, s_tokenId);
    //     _setTokenURI(s_tokenId, tokenURI);

    //     createListedToken(s_tokenId, price);

    //     s_tokenId = s_tokenId + 1;

    //     return s_tokenId - 1;
    // }

    // function createListedToken(uint256 _tokenId, uint256 _price) private {
    //     s_tokenIdToListedToken[_tokenId] = ListedToken({
    //         tokenId: _tokenId,
    //         owner: payable(address(this)),
    //         seller: payable(msg.sender),
    //         price: _price,
    //         currentlyListed: true
    //     });

    //     _transfer(msg.sender, address(this), _tokenId);

    //     emit TokenListedSuccess(_tokenId, address(this), msg.sender, _price, true);
    // }

    // function getAllNFTs() external view returns (ListedToken[] memory) {
    //     ListedToken[] memory allNfts = new ListedToken[](s_tokenId);

    //     for (uint256 i = 0; i < s_tokenId; i++) {
    //         allNfts[i] = s_tokenIdToListedToken[i];
    //     }

    //     return allNfts;
    // }

    // function executeSale(uint256 tokenId) external payable {
    //     uint256 price = s_tokenIdToListedToken[tokenId].price;

    //     if (msg.value != price) {
    //         revert NFTMarketplace__IncorrectPrice();
    //     }

    //     address seller = s_tokenIdToListedToken[tokenId].seller;

    //     s_tokenIdToListedToken[tokenId].seller = payable(msg.sender);

    //     _transfer(address(this), msg.sender, tokenId);

    //     // If the new owner plans to sell the nft later, new owner has to approve
    //     approve(address(this), tokenId);

    //     s_itemsSold = s_itemsSold + 1;

    //     (bool sendListingFee,) = payable(i_owner).call{value: s_listingPrice}("");

    //     if (!sendListingFee) {
    //         revert NFTMarketplace__TransferFailed();
    //     }

    //     (bool sendAmountToSeller,) = payable(seller).call{value: price}("");

    //     if (!sendAmountToSeller) {
    //         revert NFTMarketplace__TransferFailed();
    //     }
    // }
}
