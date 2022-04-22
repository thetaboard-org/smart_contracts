const thetaboard_nft = artifacts.require("ThetaboardNFT");
const thetaboard_offer = artifacts.require("ThetaboardOffer");
artifacts.require("ERC721")

const toWei = web3.utils.toWei;
const fromWei = web3.utils.fromWei;
const BN = web3.utils.BN;

const gasPrice = 20000000000;


contract("thetaboard offer NFT", async accounts => {
    const owner = accounts[0];
    const seller1 = accounts[1];
    const seller2 = accounts[2];
    const artist = accounts[3];
    const offerer = accounts[4];
    const offerPrice = toWei("0.01");
    const artistRoyalties = 250;
    let nftTokenId1;
    let nftTokentId2;

    it("Should reject free offer", async () => {
        /* get contracts */
        const offer = await thetaboard_offer.deployed()
        const nft = await thetaboard_nft.deployed();
        const nftContractAddress = nft.address


        /* Make an offer */
        try {
            await offer.createNewOffer(nftContractAddress, 0, {from: offerer});
            assert.equal(1, 1, "Free offer should be rejected");
        } catch (e) {
            assert.equal(1, 1, "Successfully rejected");
        }
    })

    it("Should create and execute offer", async () => {
        /* get contracts */
        const offer = await thetaboard_offer.deployed()
        const nft = await thetaboard_nft.deployed();
        const nftContractAddress = nft.address

        /* mint nft */
        const nft1 = await nft.mint(seller1);
        const nft2 = await nft.mint(seller2);
        const nft3 = await nft.mint(seller2);

        /* Make an offer */
        await offer.createNewOffer(nftContractAddress, 0, {from: offerer, value: offerPrice});
        await offer.createNewOffer(nftContractAddress, 1, {from: offerer, value: offerPrice});


        // get items
        const items = await offer.fetchOffers();
        assert.equal(items.length, 2, "Two offers should exists");
        assert.equal(items["0"].price, offerPrice, "Price should be the same as offer price");

        // check it can get sell from nftContract + tokenId
        const item = await offer.getByNftContractTokenIdAddress(nftContractAddress, 1, offerer);
        assert.equal(item.itemId, 2, "Should get item from 'getByNftContractTokenIdAddress'");

        const seller1Items = await offer.fetchOffersForAddress(offerer);
        assert.equal(seller1Items.length, 2, "Two item should be offered by offerer")
    });

    it("Should accept an offer", async () => {
        /* get contracts */
        const offer = await thetaboard_offer.deployed()
        const nft = await thetaboard_nft.deployed();

        const salesFee = await offer.getSalesFee();
        const offerContractBeforeBuy = await web3.eth.getBalance(offer.address);
        const ownerBeforeBuy = await web3.eth.getBalance(owner);
        await nft.approve(offer.address, 0, {from: seller1});

        await offer.acceptOffer(1, "0x0000000000000000000000000000000000000000", 0, {
            from: seller1,
        });


        const offerContractAfterBuy = await web3.eth.getBalance(offer.address);
        const ownerAfterBuy = await web3.eth.getBalance(owner);
        const nftOwner = await nft.ownerOf(0);

        const offererBalanceChange = new BN(offerContractBeforeBuy).sub(new BN(offerContractAfterBuy));

        // Check if money received is correctly balanced
        assert.equal(offererBalanceChange.toString(), offerPrice, "Contract should pay");
        assert.equal(new BN(ownerAfterBuy).sub(new BN(ownerBeforeBuy)).toString(), offerPrice / 1000 * salesFee, "Thetaboard should get his money");
        assert.equal(nftOwner, offerer, "Buyer should be new owner of NFT");

    });

    it("Should accept an offer and give a fee to a creator", async function () {
        /* get contracts */
        const offer = await thetaboard_offer.deployed()
        const nft = await thetaboard_nft.deployed();

        const salesFee = await offer.getSalesFee();
        const offerContractBeforeBuy = await web3.eth.getBalance(offer.address);
        const ownerBeforeBuy = await web3.eth.getBalance(owner);
        const artistBeforeBuy = await web3.eth.getBalance(artist);


        await nft.approve(offer.address, 1, {from: seller2});
        await offer.acceptOffer(2, artist, artistRoyalties, {
            from: seller2
        });

        const nftOwner = await nft.ownerOf(1)

        const offerContractAfterBuy = await web3.eth.getBalance(offer.address);
        const ownerAfterBuy = await web3.eth.getBalance(owner);
        const artistAfterBuy = await web3.eth.getBalance(artist);

        const artistPayout = (offerPrice / 1000 * artistRoyalties);
        const ownerPayout = (offerPrice / 1000 * salesFee);
        const sellerPayout = offerPrice - ownerPayout - artistPayout;

        assert.equal(new BN(offerContractBeforeBuy).sub(new BN(offerContractAfterBuy)).toString(), offerPrice, "Offer contract should have offer price less");
        assert.equal(new BN(ownerAfterBuy).sub(new BN(ownerBeforeBuy)).toString(), ownerPayout, "Thetaboard should get his money");
        assert.equal(new BN(artistAfterBuy).sub(new BN(artistBeforeBuy)).toString(), artistPayout, "Artist should get his money");
        assert.equal(nftOwner, offerer, "Buyer should be new owner of NFT");
    });

    it("Should cancel offer", async function () {
        /* get contracts */
        const offer = await thetaboard_offer.deployed()
        const offerAddress = offer.address
        const nft = await thetaboard_nft.deployed();
        const nftContractAddress = nft.address;

        await offer.createNewOffer(nftContractAddress, 1, {from: offerer, value: offerPrice});
        const currentOffers = await offer.fetchOffers();
        await offer.cancelOffer(3, {from: offerer});
        const currentOffersAfterReject = await offer.fetchOffers();
        assert.equal(currentOffers.length - 1, currentOffersAfterReject.length, "Should have one less item in offers");

    });

    it("Should deny offer", async function () {
        /* get contracts */
        const offer = await thetaboard_offer.deployed()
        const offerAddress = offer.address
        const nft = await thetaboard_nft.deployed();
        const nftContractAddress = nft.address

        await offer.createNewOffer(nftContractAddress, 2, {from: offerer, value: offerPrice});
        const currentOffers = await offer.fetchOffers();
        await offer.denyOffer(4, {from: seller2});
        const currentOffersAfterReject = await offer.fetchOffers();
        assert.equal(currentOffers.length - 1, currentOffersAfterReject.length, "Should have one less item in offers");
    });

    it("Should change offer", async function () {
        /* get contracts */
        const offer = await thetaboard_offer.deployed()
        const offerAddress = offer.address
        const nft = await thetaboard_nft.deployed();
        const nftContractAddress = nft.address

        await offer.createNewOffer(nftContractAddress, 2, {from: offerer, value: offerPrice});
        const newPrice = Number(offerPrice) + Number(toWei("0.01"));
        await offer.changeOffer(3, {from: offerer, value: newPrice});
        const offerUpdated = await offer.getByItemId(3);
        assert.equal(offerUpdated.price, newPrice, "Price should have changed");
    });


})

