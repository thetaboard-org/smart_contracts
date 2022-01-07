// migrations/2_deploy.js
// SPDX-License-Identifier: MIT
const ThetaboardNFT = artifacts.require("ThetaboardNFT");
const ThetaboardSellNft = artifacts.require("ThetaboardDirectSellNft");
const ThetaboardAuctionNft = artifacts.require("ThetaboardAuctionSellNft");
const ThetaboardMarketplace = artifacts.require('ThetaboardMarketplace');


module.exports = async function (deployer) {
    await deployer.deploy(ThetaboardNFT, "Thetaboard 2021 NFT", "TB", "https://nft.thetaboard.io/nft/2/");
     // const thetaboardNftInstance = await ThetaboardNFT.deployed();
    // const thetaboardNftInstanceAddress = thetaboardNftInstance.address;
    // // //
    // await deployer.deploy(ThetaboardSellNft);
    // const ThetaboardSellNftInstance = await ThetaboardSellNft.deployed();
    // const ThetaboardSellNftInstanceAddress = ThetaboardSellNftInstance.address;
    //
    // await deployer.deploy(ThetaboardAuctionNft);

    // const MinterRole = await thetaboardNftInstance.MINTER_ROLE();
    // await thetaboardNftInstance.grantRole(MinterRole, ThetaboardSellNftInstanceAddress);

    // await ThetaboardSellNftInstance.newSell(thetaboardNftInstanceAddress, web3.utils.toWei("20", "ether"), new Date('Sat, 01 Jan 2022 00:00:00 GMT').getTime() / 1000, 9999999, "0x965110E5FBa621cB24550e7Ad4298733df1accf5", 100);

    // MarketPlace
    await deployer.deploy(ThetaboardMarketplace);



};

