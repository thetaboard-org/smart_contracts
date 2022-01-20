pragma solidity ^0.8.0;

import "./ThetaboardNFT.sol";
import "./ThetaboardDirectSellNft.sol";
import "./ThetaboardAuctionSellNft.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";


/**
 * @title nft_sell
 * Auction NFT for thetaboard.io
 */
contract ThetaboardCreatorManager is Ownable {

    event NFTDeployed(
        address nftContract,
        string name,
        string url
    );
    event SellCreated(
        string sellType,
        address nftContract,
        uint price,
        uint endDate,
        uint editionNumber,
        address artistWallet,
        uint8 split
    );

    function createNFT(string memory name, string memory url, address[] memory toBeMinters) internal returns (address){
        ThetaboardNFT newlyCreated = new ThetaboardNFT(name, "TB", url);
        // setup roles
        bytes32 minterRole = newlyCreated.MINTER_ROLE();
        newlyCreated.grantRole(minterRole, msg.sender);
        for (uint i = 0; i < toBeMinters.length; i++) {
            newlyCreated.grantRole(minterRole, toBeMinters[i]);
        }
        // emit event
        emit NFTDeployed(
            address(newlyCreated),
            name,
            url
        );
        return address(newlyCreated);
    }


    function deployNFTandSell(string memory name, string memory url, address[] memory toBeMinters,
        address directSellContract, uint price, uint endDate,
        uint editionNumber, address artistWallet, uint8 split) external {

        address nftAddress = createNFT(name, url, toBeMinters);
        ThetaboardDirectSellNft DirectSell = ThetaboardDirectSellNft(directSellContract);
        DirectSell.newSell(nftAddress, price, endDate, editionNumber, artistWallet, split);
        emit SellCreated("direct", nftAddress, price, endDate, editionNumber, artistWallet, split);
    }

    function deployNFTandAuction(string memory name, string memory url, address[] memory toBeMinters,
        address auctionSellContract, uint minBid, uint endDate,
        uint editionNumber, address artistWallet, uint8 split) external {

        address nftAddress = createNFT(name, url, toBeMinters);
        ThetaboardAuctionSellNft AuctionSell = ThetaboardAuctionSellNft(auctionSellContract);
        AuctionSell.newAuction(nftAddress, minBid, endDate, editionNumber, artistWallet, split);
        emit SellCreated("auction", nftAddress, minBid, endDate, editionNumber, artistWallet, split);
    }
}