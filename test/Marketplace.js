const thetaboard_nft = artifacts.require("ThetaboardNFT");
const thetaboard_marketplace = artifacts.require("ThetaboardMarketplace");

const toWei = web3.utils.toWei;
const fromWei = web3.utils.fromWei;


contract("thetaboard marketplace NFT", async accounts => {
    const owner = accounts[0];
    const seller1 = accounts[1];
    const seller2 = accounts[2];
    const artist = accounts[3];
    const buyer = accounts[4];
    const sellPrice = toWei("0.01");
    const artistRoyalties = 250;

    it("Should create and execute market sales", async () => {
        /* get contracts */
        const market = await thetaboard_marketplace.deployed()
        const marketAddress = market.address
        const nft = await thetaboard_nft.deployed();
        const nftContractAddress = nft.address

        /* mint nft */
        const nft1 = await nft.mint(seller1);
        const nft2 = await nft.mint(seller2);


        /* put tokens for sale */
        await nft.approve(marketAddress, 0, {from: seller1});
        await market.createMarketItem(nftContractAddress, 0, sellPrice, "CategoryRandom", {from: seller1});
        await nft.approve(marketAddress, 1, {from: seller2});
        await market.createMarketItem(nftContractAddress, 1, sellPrice, "CategoryRandom", {from: seller2});

        // get items
        const items = await market.fetchSellingItems();
        assert.equal(items.length, 2, "Two items should be on sale");
        assert.equal(items["0"].price, sellPrice, "Price should be the same a sell price");

        const seller1Items = await market.fetchSellingItemsForAddress(seller1);
        assert.equal(seller1Items.length, 1, "One item should be sold by seller 1")
    });

    it("Should buy an item", async () => {
        /* get contracts */
        const market = await thetaboard_marketplace.deployed()
        const nft = await thetaboard_nft.deployed();


        const salesFee = await market.getSalesFee();
        const sellerBeforeBuy = await web3.eth.getBalance(seller1);
        const ownerBeforeBuy = await web3.eth.getBalance(owner);

        const buyingEvent = await market.buyFromMarket(1, "0x0000000000000000000000000000000000000000", 0, {
            from: buyer,
            value: sellPrice
        });

        const sellerAfterBuy = await web3.eth.getBalance(seller1);
        const ownerAfterBuy = await web3.eth.getBalance(owner);
        const nftOwner = await nft.ownerOf(0);

        new web3.utils.BN(sellerAfterBuy).sub(new web3.utils.BN(sellerBeforeBuy))

        // Check if money received is correctly balanced
        assert.equal(new web3.utils.BN(sellerAfterBuy).sub(new web3.utils.BN(sellerBeforeBuy)), sellPrice - (sellPrice / 1000 * salesFee), "Seller should get his money");
        assert.equal(new web3.utils.BN(ownerAfterBuy).sub(new web3.utils.BN(ownerBeforeBuy)), sellPrice / 1000 * salesFee, "Thetaboard should get his money");
        assert.equal(nftOwner, buyer, "Buyer should be new owner of NFT");

        const items = await market.fetchSellingItems();
        assert.equal(items.length, 1, "Should have only 1 item left in marketplace");


        const itemsBought = await market.fetchPurchasedItemsForAddress(buyer);
        assert.equal(itemsBought.length, 1, "Buyer should be on buyer property")
        assert.equal(itemsBought[0].buyer, buyer, "Buyer should be on buyer property")
    });

    it("Should buy an item and give a fee to a creator", async function () {
        /* get contracts */
        const market = await thetaboard_marketplace.deployed()
        const nft = await thetaboard_nft.deployed();

        const salesFee = await market.getSalesFee();
        const sellerBeforeBuy = await web3.eth.getBalance(seller2);
        const ownerBeforeBuy = await web3.eth.getBalance(owner);
        const artistBeforeBuy = await web3.eth.getBalance(artist);

        const buyingEvent = await market.buyFromMarket(2, artist, artistRoyalties, {
            from: buyer,
            value: sellPrice
        });

        const sellerAfterBuy = await web3.eth.getBalance(seller2);
        const ownerAfterBuy = await web3.eth.getBalance(owner);
        const artistAfterBuy = await web3.eth.getBalance(artist);
        const nftOwner = await nft.ownerOf(1);

        const artistPayout = (sellPrice / 1000 * artistRoyalties);
        const ownerPayout = (sellPrice / 1000 * salesFee);
        const sellerPayout = sellPrice - ownerPayout - artistPayout;

        assert.equal(new web3.utils.BN(sellerAfterBuy).sub(new web3.utils.BN(sellerBeforeBuy)), sellerPayout, "Seller should get his money");
        assert.equal(new web3.utils.BN(ownerAfterBuy).sub(new web3.utils.BN(ownerBeforeBuy)), ownerPayout, "Thetaboard should get his money");
        assert.equal(new web3.utils.BN(artistAfterBuy).sub(new web3.utils.BN(artistBeforeBuy)), artistPayout, "Artist should get his money");
        assert.equal(nftOwner, buyer, "Buyer should be new owner of NFT");
    });


    it("Should cancel a sell", async function () {
        /* get contracts */
        const market = await thetaboard_marketplace.deployed()
        const marketAddress = market.address
        const nft = await thetaboard_nft.deployed();
        const nftContractAddress = nft.address

        /* mint nft */
        const nft1 = await nft.mint(seller1);

        await nft.approve(marketAddress, 2, {from: seller1});
        await market.createMarketItem(nftContractAddress, 2, sellPrice, "CategoryRandom", {from: seller1});
        await market.cancelMarketItem(3, {from: seller1});
        const itemsBought = await market.fetchPurchasedItemsForAddress(seller1);
        assert.equal(itemsBought[0].itemId, 3, "Third item should be considered sold");
        assert.equal(itemsBought[0].buyer, seller1, "Seller is the same as Buyer");
    });


    it("Should hange sell fee", async function () {
        /* get contracts */
        const market = await thetaboard_marketplace.deployed()

        // set fee
        await market.setSalesFeeBasisPoints(300);
        const salesFee = await market.getSalesFee();

        assert.equal(salesFee, 300, "Sales fee should be at 300");
    });

})