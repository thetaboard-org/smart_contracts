pragma solidity ^0.8.0;

import "./ThetaboardNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title nft_sell
 * sell NFT for thetaboard.io
 */
contract ThetaboardDirectSellNft is Ownable {

    struct nftSell {
        uint256 price;
        uint256 maxDate;
        uint256 maxMint;
        address artistWallet;
        uint8 artistSplit;
    }

    mapping(address => nftSell) NFTsSell;

    /**
    * @dev enable a new NFT to be minted from this contract
    * @dev _nftAddress and _nftPrice are required
    * _maxDate and _maxMint are optionals ( can be passed ar 0 to be ignored)
    * _artistSplit percentage of the sells will be send to _artistWallet
    */
    function newSell(address _nftAddress, uint256 _nftPrice, uint256 _maxDate, uint256 _maxMint, address _artistWallet, uint8 _artistSplit) public onlyOwner {
        require(_nftAddress != address(0) && _nftAddress != address(this));
        require(NFTsSell[_nftAddress].price == 0, "contract already exists for this nft");
        require(_nftPrice > 0, "A price is required");
        require(_maxDate == 0 || _maxDate > block.timestamp, "if date is passed, it must higher than current");
        NFTsSell[_nftAddress] = nftSell({
        price : _nftPrice,
        maxDate : _maxDate,
        maxMint : _maxMint,
        artistWallet : _artistWallet,
        artistSplit : _artistSplit
        });
    }

    /**
    * @dev purchase a newly minted token from _nftAddress
    * Purchase a token
    */
    function purchaseToken(address _nftAddress) public payable {
        require(msg.sender != address(0) && msg.sender != address(this));
        require(NFTsSell[_nftAddress].price != 0, "A contract should exists for this nft");
        require(NFTsSell[_nftAddress].maxDate == 0 || NFTsSell[_nftAddress].maxDate > block.timestamp, "Can't buy after max date is passed");
        require(NFTsSell[_nftAddress].price <= msg.value, "Need to send at least the price of NFT");
        uint currentSupply = ThetaboardNFT(_nftAddress).totalSupply();
        require(NFTsSell[_nftAddress].maxMint == 0 || currentSupply < NFTsSell[_nftAddress].maxMint, "No more NFT available");
        ThetaboardNFT(_nftAddress).mint(msg.sender);

        uint artistValue = msg.value / 100 * NFTsSell[_nftAddress].artistSplit;
        uint ownerValue = msg.value - artistValue;

        payable(NFTsSell[_nftAddress].artistWallet).transfer(artistValue);
        payable(owner()).transfer(ownerValue);
    }

    /**
    * @dev Updates _price for _nftAddress
    * @dev Throws if _price is zero
    */
    function setPrice(address _nftAddress, uint256 _price) public onlyOwner {
        require(NFTsSell[_nftAddress].price != 0, "A contract should exists for this nft");
        require(_price > 0);
        NFTsSell[_nftAddress].price = _price;
    }

    /**
    * @dev Updates maxDate for _nftAddress
    * @dev Throws if date is in the past
    */
    function setMaxDate(address _nftAddress, uint256 _maxDate) public onlyOwner {
        require(NFTsSell[_nftAddress].price != 0, "A contract should exists for this nft");
        require(_maxDate == 0 || _maxDate > block.timestamp, "if date is passed, it must higher than current");
        NFTsSell[_nftAddress].maxDate = _maxDate;
    }

    /**
    * @dev Updates maxMint for _nftAddress
    */
    function setMaxMint(address _nftAddress, uint256 _maxMint) public onlyOwner {
        require(NFTsSell[_nftAddress].price != 0, "A contract should exists for this nft");
        NFTsSell[_nftAddress].maxMint = _maxMint;
    }

    /**
    * Get info about currently sold contract
    */
    function getNftSell(address _nftAddress) public view returns (nftSell memory) {
        return NFTsSell[_nftAddress];
    }

}