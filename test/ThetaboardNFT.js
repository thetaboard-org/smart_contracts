const thetaboard_nft = artifacts.require("ThetaboardNFT");
const thetaboard_sell = artifacts.require("ThetaboardDirectSellNft");
const thetaboard_auction = artifacts.require("ThetaboardAuctionSellNft");

const toWei = web3.utils.toWei;
const fromWei = web3.utils.fromWei;

contract("thetaboard Auction NFT test", async accounts => {

    const contract_owner = accounts[0];
    const artist = accounts[1];
    const bidder1 = accounts[2];
    const bidder2 = accounts[3];
    const bidder3 = accounts[4]

    const price = toWei("0.5", "ether");

    const bid1 = toWei("1", "ether");
    const bid2 = toWei("1.5", "ether");
    const bid3 = toWei("1.2", "ether");

    const artistSplit = 90;
    const maxMint = 2;

    it("can't bid without contract", async () => {
        try {
            const nft_instance = await thetaboard_nft.deployed();
            const auction_instance = await thetaboard_auction.deployed();
            const bid = await auction_instance.placeBid(nft_instance.address, {
                from: bidder1,
                value: price
            })
            assert.equal(true, false, "shouldn't have a contract");
        } catch (e) {
            assert.equal(e.reason, "A contract should exists for this nft", e);
        }
    })

    it("Should be able to create a new auction", async () => {
        try {
            const nft_instance = await thetaboard_nft.deployed();
            const auction_instance = await thetaboard_auction.deployed();
            const blockNum = await web3.eth.getBlockNumber();
            const block = await web3.eth.getBlock(blockNum);
            const ts = block['timestamp'];
            await auction_instance.newAuction(nft_instance.address, price, ts + 1000, maxMint, artist, artistSplit,
                {from: accounts[1]});
            const contract = await auction_instance.getNftAuction(nft_instance.address);
            assert.equal(contract.minBid, price);
            assert.equal(contract.maxDate, ts + 1000);
            assert.equal(contract.maxMint, maxMint);
            assert.equal(contract.countBidMade, 0);
            assert.equal(contract.artistWallet, artist);
            assert.equal(contract.artistSplit, 90);
            assert.equal(contract.auctionOwner, accounts[1]);
        } catch (e) {
            assert.equal(true, false, e);
        }
    })

    it("Should be able to place bid", async () => {
        const nft_instance = await thetaboard_nft.deployed();
        const auction_instance = await thetaboard_auction.deployed();
        await auction_instance.placeBid(nft_instance.address, {
            from: bidder1,
            value: bid1
        });
        const contract = await auction_instance.getNftAuction(nft_instance.address);
        assert.equal(contract.countBidMade, 1);
        assert.equal(contract.bidders[0], bidder1);
        assert.equal(contract.bidsValue[0], bid1);

    })

    it("new Bids ", async () => {
        const nft_instance = await thetaboard_nft.deployed();
        const auction_instance = await thetaboard_auction.deployed();

        const balanceBeforeReplaced = await web3.eth.getBalance(bidder1);

        await auction_instance.placeBid(nft_instance.address, {
            from: bidder2,
            value: bid2
        });
        await auction_instance.placeBid(nft_instance.address, {
            from: bidder3,
            value: bid3
        });
        const balanceAfterReplaced = await web3.eth.getBalance(bidder1);

        const contract = await auction_instance.getNftAuction(nft_instance.address);

        assert.equal(contract.minBid, contract.minBid);
        assert.equal(contract.bidders.length, 2);
        assert.equal(contract.bidsValue.length, 2);
        assert.equal(contract.bidders[0], bidder3);
        assert.equal(contract.bidsValue[0], bid3);
        assert.equal(fromWei(balanceBeforeReplaced), fromWei(balanceAfterReplaced) - fromWei(bid1), "Bidder 1 should get his money back")
    })

    it("Can't bid if offer is lower than lowest bid", async () => {
        const nft_instance = await thetaboard_nft.deployed();
        const auction_instance = await thetaboard_auction.deployed();
        try {
            await auction_instance.placeBid(nft_instance.address, {
                from: bidder1,
                value: bid1
            });
            assert.equal(true, false, "Should not have been able to bid");
        } catch (e) {
            assert.equal(e.reason, "Bid should be higher than minBid");
        }
    });

    it("Should not be able to buy after bidding phase is done", async () => {
        const advanceBlockAtTime = (time) => {
            return new Promise((resolve, reject) => {
                web3.currentProvider.send(
                    {
                        method: "evm_mine",
                        params: [time],
                    },
                    (err, _) => {
                        if (err) {
                            return reject(err);
                        }
                        return resolve();
                    },
                );
            });
        };

        const nft_instance = await thetaboard_nft.deployed();
        const auction_instance = await thetaboard_auction.deployed();
        const contract = await auction_instance.getNftAuction(nft_instance.address);
        try {
            await advanceBlockAtTime(contract.maxDate);
            await auction_instance.placeBid(nft_instance.address, {
                from: bidder2,
                value: bid2
            });
            assert.equal(true, false, "Should not have been able to bid");
        } catch (e) {
            assert.equal(e.reason, "Can't bid after max date is passed", e);
        }
    });

    it("Can conclude auction, and everyone get NFT and payment", async () => {
        const nft_instance = await thetaboard_nft.deployed();
        const auction_instance = await thetaboard_auction.deployed();
        let contract = await auction_instance.getNftAuction(nft_instance.address);

        // Enable minter role
        const MinterRole = await nft_instance.MINTER_ROLE()
        await nft_instance.grantRole(MinterRole, auction_instance.address);

        // get an ordered array with index order of highest to lowest bid
        const bidsValue = contract.bidsValue.map(Number);
        const bidsValueSorted = [...bidsValue].sort((a, b) => b - a);
        const indices = bidsValue.map(x => bidsValueSorted.indexOf(x));

        // Get balances
        const balanceBeforeArtist = await web3.eth.getBalance(artist);
        const balanceBeforeOwner = await web3.eth.getBalance(contract_owner);

        const receipt = await auction_instance.concludeAuction(nft_instance.address, indices);
        const tx = await web3.eth.getTransaction(receipt.tx);
        contract = await auction_instance.getNftAuction(nft_instance.address);

        // Check if owners are in the correct order:
        const owner_id_0 = await nft_instance.ownerOf(0);
        const owner_id_1 = await nft_instance.ownerOf(1);
        assert.equal(owner_id_0, bidder2, "Bidder 2 should have first token");
        assert.equal(owner_id_1, bidder3, "Bidder 1 should have second token");

        // check balances
        const balanceAfterArtist = await web3.eth.getBalance(artist);
        const balanceAfterOwner = await web3.eth.getBalance(contract_owner);
        const total_price = contract.bidsValue.reduce((sum, bid) => sum + Number(bid), 0);
        const artistSplit = contract.artistSplit;

        const owner_gains = Number(balanceAfterOwner) - Number(balanceBeforeOwner);
        const artist_gains = Number(balanceAfterArtist) - Number(balanceBeforeArtist);
        const tx_price = receipt.receipt.cumulativeGasUsed * tx.gasPrice;
        // rounded because the tx_price is not correct;
        const rounded_owner_gains = toWei(String(Number(fromWei(String(owner_gains + tx_price))).toFixed(6)))
        assert.equal(artist_gains, Number(total_price) / 100 * artistSplit,
            "Artist doesn't have his share");
        assert.equal(rounded_owner_gains,
            Number(total_price) - (Number(total_price) / 100 * artistSplit),
            "Owner doesn't have his share");

        assert(contract.concluded, true, "Auction should be concluded");

    });

});

contract("thetaboard NFT", async accounts => {
    const contract_owner = accounts[0];
    const nft_minter = accounts[3];

    it("mint NFT", async () => {
        try {
            const nft_instance = await thetaboard_nft.deployed();
            const name = await nft_instance.name();
            const nft = await nft_instance.mint(nft_minter);
            const owner = await nft_instance.ownerOf(0);

            assert.equal(owner, nft_minter, "Not the right owner")
        } catch (e) {
            assert.equal(true, false, e);
        }
    });
})


contract("thetaboard Sell NFT test", async accounts => {

    const contract_owner = accounts[0];
    const nft_buyer = accounts[1];
    const artist = accounts[2];

    const price = toWei("0.01", "ether");
    const artistSplit = 100;
    const maxMint = 1;

    it("can't create without contract", async () => {
        try {
            const nft_instance = await thetaboard_nft.deployed();
            const sell_instance = await thetaboard_sell.deployed();
            const contract = await sell_instance.getNftSell(nft_instance.address);

            const bough_token = await sell_instance.purchaseToken(nft_instance.address, {
                from: nft_buyer,
                value: price
            })
            assert.equal(true, false, "shouldn't have a contract");
        } catch (e) {
            assert.equal(e.reason, "A contract should exists for this nft", e);
        }
    })

    it("Should be able to create a new contract", async () => {
        try {
            const nft_instance = await thetaboard_nft.deployed();
            const sell_instance = await thetaboard_sell.deployed();
            await sell_instance.newSell(nft_instance.address, price, 0, maxMint, artist, artistSplit);
            const contract = await sell_instance.getNftSell(nft_instance.address);
            assert.equal(contract.price, price);
            assert.equal(contract.maxDate, 0);
            assert.equal(contract.maxMint, maxMint);
            assert.equal(contract.artistWallet, artist);
            assert.equal(contract.artistSplit, artistSplit);
        } catch (e) {
            assert.equal(true, false, e);
        }
    })

    it("Should not be able to buy without minter role", async () => {
        try {
            const nft_instance = await thetaboard_nft.deployed();
            const sell_instance = await thetaboard_sell.deployed();

            await sell_instance.purchaseToken(nft_instance.address, {
                from: nft_buyer,
                value: price
            });
            assert.equal(true, false, "should no be able to buy");
        } catch (e) {
            assert.equal(e.reason, "ERC721PresetMinterPauserAutoId: must have minter role to mint", e);
        }
    });

    it("Should be able to buy token", async () => {
        const nft_instance = await thetaboard_nft.deployed();
        const sell_instance = await thetaboard_sell.deployed();
        const MinterRole = await nft_instance.MINTER_ROLE()
        await nft_instance.grantRole(MinterRole, sell_instance.address);

        const balanceBeforeArtist = await web3.eth.getBalance(artist);
        const balanceBeforeOwner = await web3.eth.getBalance(contract_owner);

        const bough_token = await sell_instance.purchaseToken(nft_instance.address, {
            from: nft_buyer,
            value: price
        })
        try{
            const owner = await nft_instance.ownerOf(0);
            const balanceAfterArtist = await web3.eth.getBalance(artist);
            const balanceAfterOwner = await web3.eth.getBalance(contract_owner);

            assert.equal(Number(balanceAfterArtist) - Number(balanceBeforeArtist), Number(price) / 100 * artistSplit, "Artist doesn't have his share");
            assert.equal(Number(balanceAfterOwner) - Number(balanceBeforeOwner), Number(price) - (Number(price) / 100 * artistSplit), "Owner doesn't have his share");
            assert.equal(owner, nft_buyer);
        }catch (e) {
            assert.equal(true, false, e)
        }
    })

    it("Should not be able to buy token after max mint is reached", async () => {
        const nft_instance = await thetaboard_nft.deployed();
        const sell_instance = await thetaboard_sell.deployed();
        try {
            const bough_token = await sell_instance.purchaseToken(nft_instance.address, {
                from: nft_buyer,
                value: price
            });
            assert.equal(true, false, "Should not have been able to buy");
        } catch (e) {
            assert.equal(e.reason, "No more NFT available");
        }

    });

    it("Should be able to buy before max date", async () => {
        const nft_instance = await thetaboard_nft.deployed();
        const sell_instance = await thetaboard_sell.deployed();
        const blockNum = await web3.eth.getBlockNumber();
        const block = await web3.eth.getBlock(blockNum);
        const ts = block['timestamp'];
        await sell_instance.setMaxDate(nft_instance.address, ts + 1000);
        await sell_instance.setMaxMint(nft_instance.address, 3);
        try {
            await sell_instance.purchaseToken(nft_instance.address, {
                from: nft_buyer,
                value: price
            });
            const owner = await nft_instance.ownerOf(2);
            assert.equal(owner, nft_buyer)
        } catch (e) {
            assert.equal(true, false, e);
        }
    });


    it("Buying after max date returns an error", async () => {
        const advanceBlockAtTime = (time) => {
            return new Promise((resolve, reject) => {
                web3.currentProvider.send(
                    {
                        method: "evm_mine",
                        params: [time],
                    },
                    (err, _) => {
                        if (err) {
                            return reject(err);
                        }
                        return resolve();
                    },
                );
            });
        };

        const nft_instance = await thetaboard_nft.deployed();
        const sell_instance = await thetaboard_sell.deployed();
        const blockNum = await web3.eth.getBlockNumber();
        const block = await web3.eth.getBlock(blockNum);
        const ts = block['timestamp'];
        try {
            await advanceBlockAtTime(ts + 1000);
            const bough_token = await sell_instance.purchaseToken(nft_instance.address, {
                from: nft_buyer,
                value: price
            });
            assert.equal(true, false, "Should not have been able to buy");
        } catch (e) {
            assert.equal(e.reason, "Can't buy after max date is passed", e);
        }
    });


});





