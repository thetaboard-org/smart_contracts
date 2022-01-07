pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract ThetaboardMarketPlace is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; // Id for each individual item
    Counters.Counter private _itemsSold; // Number of items sold

    address payable owner; // The owner of the NFTMarket contract
    uint256 salesFeeBasisPoints = 25; // % of split for thetaboard
    bool public listingIsActive = true;

    constructor() {
        owner = payable(msg.sender);
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable buyer;
        uint256 highestOffer;
        address payable bidder;
        string category;
        uint256 price;
        bool isSold;
    }

    struct Creator {
        address creator;
        uint256 feeBasisPoints;
    }

    //    mapping that keeps all items ever placed on the marketplace
    mapping(uint256 => MarketItem) private idToMarketItem;

    // Event called when a new Item is created
    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        string category,
        uint256 price,
        bool isSold
    );

    // Event called when an Item is sold
    event MarketItemSale(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        string category,
        uint256 price,
        bool isSold
    );

    // Event when someone places a bid
    event PlaceBid(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 highestOffer,
        address bidder,
        string category,
        uint256 price
    );

    //  Event called TFuel is spit into creator fee, thetaboard fee and payment to seller
    event FeeSplit(
        uint256 userPayout,
        address userAddress,
        uint256 ownerPayout,
        address ownerAddress,
        uint256 creatorPayout,
        address creatorAddress
    );

    function getSalesFee() public view returns (uint256) {
        return salesFeeBasisPoints;
    }

    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        string calldata category
    ) public nonReentrant {
        require(listingIsActive == true, "Listing disabled");
        require(price > 0, "No item for free here");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)), // No buyer for the item
            0, // No offer
            payable(address(0)), // No bidder
            category,
            price,
            false
        );
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            category,
            price,
            false
        );
    }

    function buyFromMarket(uint256 itemId, address creator, uint256 creatorSplit) public payable nonReentrant
    {
        require(idToMarketItem[itemId].isSold == false, "Item is already sold");

        // get sell info
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        address addressNFT = idToMarketItem[itemId].nftContract;
        address payable seller = idToMarketItem[itemId].seller;
        string memory category = idToMarketItem[itemId].category;

        require(msg.value == price, "Please make the price to be same as listing price");

        // set in marketItem
        idToMarketItem[itemId].isSold = true;
        idToMarketItem[itemId].buyer = payable(msg.sender);

        _itemsSold.increment();


        // Calculate Payouts
        uint256 creatorPayout = 0;
        uint256 ownerPayout = msg.value / 1000 * salesFeeBasisPoints;
        uint256 userPayout = 0;
        if (creator != address(0x0) && creatorSplit > 0 && creatorSplit < 975) {
            creatorPayout = msg.value / 1000 * creatorSplit;
            payable(creator).transfer(creatorPayout);
            userPayout = msg.value - creatorPayout - ownerPayout;
        } else {
            userPayout = msg.value - ownerPayout;
        }

        // Payout to user and thetaboard
        seller.transfer(userPayout);
        owner.transfer(ownerPayout);

        // transfer token
        IERC721(addressNFT).transferFrom(address(this), msg.sender, tokenId);


        emit MarketItemSale(
            itemId,
            addressNFT,
            tokenId,
            seller,
            msg.sender,
            category,
            price,
            true
        );

        emit FeeSplit(
            userPayout,
            seller,
            ownerPayout,
            owner,
            creatorPayout,
            creator
        );
    }

    function cancelMarketItem(uint256 itemId) public nonReentrant {
        require(msg.sender == idToMarketItem[itemId].seller, "You have to be the seller to cancel");
        require(idToMarketItem[itemId].isSold == false, "Item is already sold");

        // Read data from mappings
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        address nftContract = idToMarketItem[itemId].nftContract;

        // set in marketItem
        idToMarketItem[itemId].price = 0;
        idToMarketItem[itemId].isSold = true;
        idToMarketItem[itemId].buyer = idToMarketItem[itemId].seller;

        IERC721(nftContract).transferFrom(address(this), idToMarketItem[itemId].seller, tokenId);

        _itemsSold.increment();

        // Through event
        emit MarketItemSale(
            itemId,
            idToMarketItem[itemId].nftContract,
            idToMarketItem[itemId].tokenId,
            idToMarketItem[itemId].seller,
            idToMarketItem[itemId].buyer,
            idToMarketItem[itemId].category,
            0,
            true
        );
    }

    function fetchSellingItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory marketItems = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].buyer == address(0)) {
                uint256 currentId = idToMarketItem[i + 1].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                marketItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return marketItems;
    }

    function fetchPurchasedItemsForAddress(address buyer) public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].buyer == buyer) {
                itemCount += 1;
            }
        }

        MarketItem[] memory marketItems = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].buyer == buyer) {
                uint256 currentId = idToMarketItem[i + 1].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                marketItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return marketItems;
    }

    function fetchSellingItemsForAddress(address seller) public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == seller) {
                itemCount += 1;
            }
        }

        MarketItem[] memory marketItems = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == seller) {
                uint256 currentId = idToMarketItem[i + 1].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                marketItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return marketItems;
    }

    function getItemsByCategory(string calldata category) public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                keccak256(abi.encodePacked(idToMarketItem[i + 1].category)) ==
                keccak256(abi.encodePacked(category)) &&
                idToMarketItem[i + 1].buyer == address(0)
            ) {
                itemCount += 1;
            }
        }

        MarketItem[] memory marketItems = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                keccak256(abi.encodePacked(idToMarketItem[i + 1].category)) ==
                keccak256(abi.encodePacked(category)) &&
                idToMarketItem[i + 1].buyer == address(0)
            ) {
                uint256 currentId = idToMarketItem[i + 1].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                marketItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return marketItems;
    }

    function getByMarketId(uint256 id) public view returns (MarketItem memory){
        require(id <= _itemIds.current(), "id doesn't exist");
        return idToMarketItem[id];
    }

    fallback() payable external {}

    receive() external payable {}

    function retrieveMoney(uint256 amount) external {
        require(msg.sender == owner, "Only owner can retrieve Money");
        require(amount <= address(this).balance, "You can not withdraw more money than there is");
        payable(owner).transfer(amount);
    }

    function setSalesFeeBasisPoints(uint256 fee) external {
        require(msg.sender == owner, "Only owner can set listingPrice");
        require(fee <= 1000, "Sales Fee cant be higher than 10%");
        salesFeeBasisPoints = fee;
    }
}