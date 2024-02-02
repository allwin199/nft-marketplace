// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMarketplace is ERC721URIStorage {
    error NFTMarketplace__OnlyOwnerCan_UpdateListPrice();
    error NFTMarketplace__IncorrectPrice();
    error NFTMarketplace__PriceCannot_BeZero();
    error NFTMarketplace__TransferFailed();

    event TokenListedSuccess(
        uint256 indexed tokenId, address indexed owner, address indexed seller, uint256 price, bool currentlyListed
    );

    address payable private immutable i_owner;

    uint256 private s_tokenId;
    uint256 private s_itemsSold;

    uint256 private s_listPrice = 0.01 ether;

    constructor() ERC721("NFTMarketplace", "NFTM") {
        i_owner = payable(msg.sender);
    }

    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
    }

    mapping(uint256 tokenId => ListedToken) private s_tokenIdToListedToken;

    function updateListPrice(uint256 newPrice) external {
        if (msg.sender != i_owner) {
            revert NFTMarketplace__OnlyOwnerCan_UpdateListPrice();
        }
        s_listPrice = newPrice;
    }

    function getListPrice() external view returns (uint256) {
        return s_listPrice;
    }

    function getLatestListedToken() external view returns (ListedToken memory) {
        return s_tokenIdToListedToken[s_tokenId - 1];
    }

    function getListedForTokenId(uint256 tokenId) external view returns (ListedToken memory) {
        return s_tokenIdToListedToken[tokenId];
    }

    function getCurrentTokenId() external view returns (uint256) {
        return s_tokenId;
    }

    function createToken(string memory tokenURI, uint256 price) public payable returns (uint256) {
        if (msg.value != s_listPrice) {
            revert NFTMarketplace__IncorrectPrice();
        }

        if (price == 0) {
            revert NFTMarketplace__PriceCannot_BeZero();
        }

        _safeMint(msg.sender, s_tokenId);
        _setTokenURI(s_tokenId, tokenURI);

        createListedToken(s_tokenId, price);

        s_tokenId = s_tokenId + 1;

        return s_tokenId - 1;
    }

    function createListedToken(uint256 _tokenId, uint256 _price) private {
        s_tokenIdToListedToken[_tokenId] = ListedToken({
            tokenId: _tokenId,
            owner: payable(address(this)),
            seller: payable(msg.sender),
            price: _price,
            currentlyListed: true
        });

        _transfer(msg.sender, address(this), _tokenId);

        emit TokenListedSuccess(_tokenId, address(this), msg.sender, _price, true);
    }

    function getAllNFTs() external view returns (ListedToken[] memory) {
        ListedToken[] memory allNfts = new ListedToken[](s_tokenId - 1);

        for (uint256 i = 0; i < s_tokenId; i++) {
            allNfts[i] = s_tokenIdToListedToken[i];
        }

        return allNfts;
    }

    function executeSale(uint256 tokenId) external payable {
        uint256 price = s_tokenIdToListedToken[tokenId].price;

        if (msg.value != price) {
            revert NFTMarketplace__IncorrectPrice();
        }

        address seller = s_tokenIdToListedToken[tokenId].seller;

        s_tokenIdToListedToken[tokenId].seller = payable(msg.sender);

        _transfer(address(this), msg.sender, tokenId);

        // If the new owner plans to sell the nft later, new owner has to approve
        approve(address(this), tokenId);

        s_itemsSold = s_itemsSold + 1;

        (bool sendListingFee,) = payable(i_owner).call{value: s_listPrice}("");

        if (!sendListingFee) {
            revert NFTMarketplace__TransferFailed();
        }

        (bool sendAmountToSeller,) = payable(seller).call{value: price}("");

        if (!sendAmountToSeller) {
            revert NFTMarketplace__TransferFailed();
        }
    }
}
