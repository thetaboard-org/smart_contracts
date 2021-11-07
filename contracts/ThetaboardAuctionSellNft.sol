pragma solidity ^0.8.0;

import "./ThetaboardNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title nft_sell
 * Auction NFT for thetaboard.io
 */
contract ThetaboardAuctionSellNft is Ownable {

    struct nftAuction {
        uint256 maxDate;
        uint256 maxMint;

        uint256 countBidMade;
        uint256 minBid;

        address artistWallet;
        uint8 artistSplit;

        address[] bidders;
        uint256[] bidsValue;
    }

    mapping(address => nftAuction) NFTsAuction;


    // Following variables are used for sorting
    struct bidStruct {
        address bidder;
        uint256 bidValue;
    }

    mapping(uint => uint) helper;


    function newAuction(address _nftAddress, uint256 _minBid, uint256 _maxDate, uint256 _maxMint, address _artistWallet, uint8 _artistSplit) public onlyOwner {
        require(_nftAddress != address(0) && _nftAddress != address(this));
        require(NFTsAuction[_nftAddress].minBid == 0, "contract already exists for this nft");
        require(_minBid > 0, "A price is required");
        require(_maxDate == 0 || _maxDate > block.timestamp, "if date is passed, it must higher than current");

        address[] memory bidders;
        uint256[] memory bidsValue;

        NFTsAuction[_nftAddress] = nftAuction({
        maxDate : _maxDate,
        maxMint : _maxMint,
        countBidMade : 0,
        minBid : _minBid,
        artistWallet : _artistWallet,
        artistSplit : _artistSplit,
        bidders : bidders,
        bidsValue : bidsValue
        });
    }

    /**
    * @dev Add a new pid for an NFT
    * @dev Throws if contract does not exists or if the bid is not higher than minBid
    */
    function placeBid(address _nftAddress) public payable {
        require(_nftAddress != address(0) && _nftAddress != address(this));
        require(NFTsAuction[_nftAddress].minBid != 0, "A contract should exists for this nft");
        require(msg.value > NFTsAuction[_nftAddress].minBid, "Bid Should be higher than minBid");
        uint256 _bid = msg.value;
        address _bidder = msg.sender;
        if (NFTsAuction[_nftAddress].bidders.length < NFTsAuction[_nftAddress].maxMint) {
            NFTsAuction[_nftAddress].bidders.push(_bidder);
            NFTsAuction[_nftAddress].bidsValue.push(_bid);
            if (NFTsAuction[_nftAddress].bidders.length == NFTsAuction[_nftAddress].maxMint) {
                // get new min
                uint256 newMin = type(uint256).max;

                for (uint i = 0; i < NFTsAuction[_nftAddress].bidsValue.length; i++) {
                    uint256 currentBid = NFTsAuction[_nftAddress].bidsValue[i];
                    if (currentBid != NFTsAuction[_nftAddress].minBid && currentBid < newMin) {
                        newMin = currentBid;
                    }
                }
                NFTsAuction[_nftAddress].minBid = newMin;
            }
        } else {
            // send back the money
            // get new minBid, and index of current minBid
            uint256 newMin = type(uint256).max;
            uint256 currentLowestIdx;
            for (uint i = 0; i < NFTsAuction[_nftAddress].bidsValue.length; i++) {
                uint256 currentBid = NFTsAuction[_nftAddress].bidsValue[i];
                if (currentBid == NFTsAuction[_nftAddress].minBid) {
                    currentLowestIdx = i;
                }

                if (currentBid != NFTsAuction[_nftAddress].minBid && currentBid < newMin) {
                    newMin = currentBid;
                }
            }
            if (_bid < newMin) {
                newMin = _bid;
            }

            NFTsAuction[_nftAddress].minBid = newMin;
            // send money back to bidder that had previous min

            payable(NFTsAuction[_nftAddress].bidders[currentLowestIdx]).transfer(NFTsAuction[_nftAddress].bidsValue[currentLowestIdx]);
            // set new bid
            NFTsAuction[_nftAddress].bidders[currentLowestIdx] = _bidder;
            NFTsAuction[_nftAddress].bidsValue[currentLowestIdx] = _bid;

        }
        NFTsAuction[_nftAddress].countBidMade += 1;
    }


    // used
    function sort(bidStruct[] bidStructArray) private returns (bidStruct[] memory) {
        for (uint i = 0; i < bidStructArray.length; i++) {
            helper[i] = 0;
            for (uint j = 0; j < i; j++) {
                if (bidStructArray[i].bidValue < bidStructArray[j].bidValue) {
                    if (helper[i] == 0) {
                        helper[i] = helper[j];
                    }
                    helper[j] = helper[j] + 1;
                }
            }
            if (helper[i] == 0) {
                helper[i] = i + 1;
            }
        }
        var lengthSortedArray = sortedArray.length;
        for (uint i = 0; i < bidStructArray.length; i++) {
            if (i < lengthSortedArray) continue;
            sortedArray.push(bidStruct(msg.sender, 0));
        }

        /** Go over the bidStructArray and copy the items to sortedArray to the positions specified in
         ** the helper mapping. At this point subtract the added 1, to get the real index */
        for (uint i = 0; i < bidStructArray.length; i++) {
            sortedArray[helper[i] - 1] = bidStructArray[i];
        }
        return sortedArray;
    }

    function concludeBid(address _nftAddress) public onlyOwner {
        require(NFTsAuction[_nftAddress].minBid != 0, "A contract should exists for this nft");

        uint256 totalBid = 0;
        bidStruct[] sortedBidStruct;

        for (uint i = 0; i < NFTsAuction[_nftAddress].bidders.length; i++) {
            bidStruct currentBid = bidStruct({
            bidder : NFTsAuction[_nftAddress].bidders[i],
            bidValue : NFTsAuction[_nftAddress].bidsValue[i]
            });
            sortedBidStruct.push(currentBid);
        }

        sortedBidStruct = sort(sortedBidStruct);
        // TODO: check if order is correct, biggest bidder should have the edition 1
        for (uint i = 0; i < sortingBidStruct.length; i++) {
            address bidder = sortingBidStruct[i].bidder;
            ThetaboardNFT(_nftAddress).mint(bidder);
            totalBid += sortedBidStruct[i].bidsValue[i];
        }

        uint artistValue = totalBid / 100 * NFTsAuction[_nftAddress].artistSplit;
        uint ownerValue = totalBid - artistValue;

        payable(NFTsAuction[_nftAddress].artistWallet).transfer(artistValue);
        payable(owner()).transfer(ownerValue);
    }


    /**
    * @dev Updates minBid for _nftAddress
    * @dev Throws if _minBid is zero
    */
    function setPrice(address _nftAddress, uint256 _minBid) public onlyOwner {
        require(NFTsAuction[_nftAddress].minBid != 0, "A contract should exists for this nft");
        require(_minBid > 0);
        require(NFTsAuction[_nftAddress].bidders.length == 0, "Can't change price after first bid was made");
        NFTsAuction[_nftAddress].minBid = _minBid;
    }

    /**
    * @dev Updates maxDate for _nftAddress
    * @dev Throws if date is in the past
    */
    function setMaxDate(address _nftAddress, uint256 _maxDate) public onlyOwner {
        require(NFTsAuction[_nftAddress].minBid != 0, "A contract should exists for this nft");
        require(_maxDate == 0 || _maxDate > block.timestamp, "if date is passed, it must higher than current");
        NFTsAuction[_nftAddress].maxDate = _maxDate;
    }

    /**
    * Get info about currently auction
    */
    function getNftAuction(address _nftAddress) public view returns (nftAuction memory) {
        return NFTsAuction[_nftAddress];
    }

}