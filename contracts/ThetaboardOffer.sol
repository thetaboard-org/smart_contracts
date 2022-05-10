pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract ThetaboardOffer is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; // Id for each individual item
    Counters.Counter private _itemsSold; // Number of items sold

    address payable owner; // The owner of the NFTMarket contract
    uint256 salesFeeBasisPoints = 25; // % of split for thetaboard
    bool public listingIsActive = true;

    constructor() {
        owner = payable(msg.sender);
    }

    struct OfferItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable offerer;
        address payable offered;
        uint256 price;
        bool isSold;
    }

    struct Creator {
        address creator;
        uint256 feeBasisPoints;
    }

    //    mapping that keeps all items ever placed on the marketplace
    mapping(uint256 => OfferItem) private idToOfferItem;
    // mapping to get an item id from "nftcontract:tokenId:address"
    mapping(string => uint256) private contractTokenAddressToId;
    // mapping to get all item ids from "nftcontract:tokenId"
    mapping(string => uint256[]) private contractTokenToIds;

    // Event called when a new Item is created
    event OfferCreated(
        uint256 itemId,
        address nftContract,
        uint256 tokenId,
        address payable offerer,
        address payable offered,
        uint256 price
    );

    // Event called when an Item is sold
    event OfferAccepted(
        uint256 itemId,
        address nftContract,
        uint256 tokenId,
        address payable offerer,
        address payable offered,
        uint256 price
    );

    event OfferDenied(
        uint256 itemId,
        address nftContract,
        uint256 tokenId,
        address payable offerer,
        address payable offered,
        uint256 price
    );

    event OfferCanceled(
        uint256 itemId,
        address nftContract,
        uint256 tokenId,
        address payable offerer,
        address payable offered,
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

    function createNewOffer(
        address nftContract,
        uint256 tokenId
    ) public nonReentrant payable {
        require(listingIsActive == true, "Listing disabled");
        require(msg.value > 0, "Offer must be higher than 0");
        string memory contractToken = string(abi.encodePacked(nftContract, tokenId, msg.sender));
        require(contractTokenAddressToId[contractToken] < 1, string(abi.encodePacked(contractTokenAddressToId[contractToken])));


        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToOfferItem[itemId] = OfferItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            msg.value,
            false
        );
        string memory contractTokenArr = string(abi.encodePacked(nftContract, tokenId));

        contractTokenAddressToId[contractToken] = itemId;
        contractTokenToIds[contractTokenArr].push(itemId);

        emit OfferCreated(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            msg.value
        );
    }

    function changeOffer(uint256 itemId) public nonReentrant payable {
        require(listingIsActive == true, "Listing disabled");
        require(msg.value > 0, "Offer must be higher than 0");
        // get sell info
        uint256 price = idToOfferItem[itemId].price;
        address payable offerer = idToOfferItem[itemId].offerer;

        require(offerer == msg.sender, "You must be offerer to change the offer");


        idToOfferItem[itemId].price = msg.value;
        offerer.transfer(price);

        emit OfferCreated(
            itemId,
            idToOfferItem[itemId].nftContract,
            idToOfferItem[itemId].tokenId,
            offerer,
            payable(address(0)),
            msg.value
        );
    }

    function acceptOffer(uint256 itemId, address creator, uint256 creatorSplit) public nonReentrant
    {
        require(idToOfferItem[itemId].isSold == false, "Item is already sold");

        // get sell info
        uint256 price = idToOfferItem[itemId].price;
        uint256 tokenId = idToOfferItem[itemId].tokenId;
        address nftContract = idToOfferItem[itemId].nftContract;
        IERC721 nft721 = IERC721(nftContract);
        address payable offerer = idToOfferItem[itemId].offerer;
        require(nft721.ownerOf(tokenId) == msg.sender, "You must be token owner to accept the offer");

        // transfer token
        IERC721(nftContract).transferFrom(address(msg.sender), offerer, tokenId);

        // set in OfferItem
        idToOfferItem[itemId].isSold = true;
        idToOfferItem[itemId].offered = payable(msg.sender);
        delete contractTokenAddressToId[string(abi.encodePacked(nftContract, tokenId, offerer))];

        _itemsSold.increment();

        // Calculate Payouts
        uint256 creatorPayout = 0;
        uint256 ownerPayout = price / 1000 * salesFeeBasisPoints;
        uint256 userPayout = 0;
        if (creator != address(0x0) && creatorSplit > 0 && creatorSplit < 975) {
            creatorPayout = price / 1000 * creatorSplit;
            payable(creator).transfer(creatorPayout);
            userPayout = price - creatorPayout - ownerPayout;
        } else {
            userPayout = price - ownerPayout;
        }

        // Payout to user and thetaboard
        payable(msg.sender).transfer(userPayout);
        owner.transfer(ownerPayout);

        emit OfferAccepted(
            itemId,
            nftContract,
            tokenId,
            offerer,
            payable(msg.sender),
            price
        );

        emit FeeSplit(
            userPayout,
            msg.sender,
            ownerPayout,
            owner,
            creatorPayout,
            creator
        );
    }

    function denyOffer(uint256 itemId) public nonReentrant {
        require(idToOfferItem[itemId].isSold == false, "Item is already sold");

        // get sell info
        uint256 price = idToOfferItem[itemId].price;
        uint256 tokenId = idToOfferItem[itemId].tokenId;
        address nftContract = idToOfferItem[itemId].nftContract;
        address payable offerer = idToOfferItem[itemId].offerer;

        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "You must be token owner to deny the offer");

        // set in OfferItem
        idToOfferItem[itemId].isSold = true;
        offerer.transfer(price);
        string memory contractToken = string(abi.encodePacked(nftContract, tokenId, offerer));
        delete contractTokenAddressToId[contractToken];
        _itemsSold.increment();

        // event
        emit OfferDenied(
            itemId,
            idToOfferItem[itemId].nftContract,
            idToOfferItem[itemId].tokenId,
            idToOfferItem[itemId].offerer,
            payable(msg.sender),
            price
        );
    }

    function cancelOffer(uint256 itemId) public nonReentrant {
        require(idToOfferItem[itemId].isSold == false, "Item is already sold");

        // get sell info
        uint256 price = idToOfferItem[itemId].price;
        uint256 tokenId = idToOfferItem[itemId].tokenId;
        address nftContract = idToOfferItem[itemId].nftContract;
        address payable offerer = idToOfferItem[itemId].offerer;

        require(offerer == msg.sender || msg.sender == owner, "You must be offerer to cancel the offer");

        // set in OfferItem
        idToOfferItem[itemId].isSold = true;
        offerer.transfer(price);
        string memory contractToken = string(abi.encodePacked(nftContract, tokenId, offerer));
        delete contractTokenAddressToId[contractToken];
        _itemsSold.increment();

        // event
        emit OfferCanceled(
            itemId,
            idToOfferItem[itemId].nftContract,
            idToOfferItem[itemId].tokenId,
            idToOfferItem[itemId].offerer,
            payable(address(0)),
            price
        );
    }

    function fetchOffers() public view returns (OfferItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        OfferItem[] memory OfferItems = new OfferItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToOfferItem[i + 1].isSold == false) {
                uint256 currentId = idToOfferItem[i + 1].itemId;
                OfferItem storage currentItem = idToOfferItem[currentId];
                OfferItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return OfferItems;
    }

    function fetchOffersByRange(uint start, uint end) public view returns (OfferItem[] memory) {
        uint256 itemCount = 0;
        uint256 currentIndex = 0;
        uint256 totalItemCount = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToOfferItem[i + 1].isSold == false) {
                itemCount += 1;
            }
        }

        OfferItem[] memory OfferItems = new OfferItem[](itemCount);
        for (uint256 i = start; i < end; i++) {
            if (idToOfferItem[i + 1].isSold == false) {
                uint256 currentId = idToOfferItem[i + 1].itemId;
                OfferItem storage currentItem = idToOfferItem[currentId];
                OfferItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return OfferItems;
    }

    function fetchOffersForAddress(address offerer) public view returns (OfferItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToOfferItem[i + 1].offerer == offerer) {
                itemCount += 1;
            }
        }

        OfferItem[] memory OfferItems = new OfferItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToOfferItem[i + 1].offerer == offerer) {
                uint256 currentId = idToOfferItem[i + 1].itemId;
                OfferItem storage currentItem = idToOfferItem[currentId];
                OfferItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return OfferItems;
    }

    function getByItemId(uint256 id) public view returns (OfferItem memory){
        require(id <= _itemIds.current(), "id doesn't exist");
        return idToOfferItem[id];
    }

    function getByNftContractTokenIdAddress(address nftContract, uint256 tokenId, address walletAddress) public view returns (OfferItem memory){
        string memory contractToken = string(abi.encodePacked(nftContract, tokenId, walletAddress));
        uint256 id = contractTokenAddressToId[contractToken];
        require(id <= _itemIds.current(), "id doesn't exist");
        return idToOfferItem[id];
    }

    function getByNftContractsTokenId(address nftContract, uint256 tokenId) public view returns (OfferItem[] memory){
        string memory contractToken = string(abi.encodePacked(nftContract, tokenId));
        uint256[] memory ids = contractTokenToIds[contractToken];
        uint256 itemCount = 0;

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            if (idToOfferItem[id].isSold == false) {
                itemCount += 1;
            }
        }
        uint256 currentIndex = 0;
        OfferItem[] memory OfferItems = new OfferItem[](itemCount);
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            if (idToOfferItem[id].isSold == false) {
                OfferItem storage currentItem = idToOfferItem[id];
                OfferItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return OfferItems;
    }

    fallback() payable external {}

    receive() external payable {}

    function setSalesFeeBasisPoints(uint256 fee) external {
        require(msg.sender == owner, "Only owner can set listingPrice");
        require(fee <= 100, "Sales Fee cant be higher than 10%");
        salesFeeBasisPoints = fee;
    }
}