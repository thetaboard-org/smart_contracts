const addressName = artifacts.require("addressName");

const toWei = web3.utils.toWei;
const fromWei = web3.utils.fromWei;
const approxeq = (v1, v2, epsilon = 0.01) => Math.abs(v1 - v2) <= epsilon;

const null_wallet = '0x0000000000000000000000000000000000000000';

const originalTfuelPrice = '5';
const newTfuelPrice = '0.0005';
const my_wallet_name = "momo";
const offerAmount = toWei("2");


contract("addressName test", async accounts => {

    it("change tfuelPrice price", async () => {
        try {
            const instance = await addressName.deployed();
            const originalPrice = await instance.tfuelPrice.call();
            await instance.setTfuelPrice(toWei(newTfuelPrice));
            const newPrice = await instance.tfuelPrice.call();
            assert.equal(originalPrice, toWei(originalTfuelPrice));
            assert.equal(newPrice, toWei(newTfuelPrice));
        } catch (e) {
            // if we have an error, we are good
            assert.equal(true, false);
        }
    });


    it("should not allow wrong price", async () => {
        try {
            const instance = await addressName.deployed();
            await instance.assignNewName(my_wallet_name, accounts[1], {from: accounts[1], value: toWei("20")});
        } catch (e) {
            // if we have an error, we are good
            assert.equal(true, true)
        }
    });

    it("should assign new name", async () => {
        try {
            const instance = await addressName.deployed();
            const newPrice = fromWei(await instance.tfuelPrice.call());
            await instance.assignNewName(my_wallet_name, accounts[1], {from: accounts[1], value: toWei(newTfuelPrice)});
            await instance.assignNewName(my_wallet_name + 'mo', accounts[1], {
                from: accounts[1],
                value: toWei(newTfuelPrice)
            });
            const nameForAddr = await instance.addressToNames.call(accounts[1], 0);
            const addrForName = await instance.nameToAddress.call(my_wallet_name);
            const getAddressToNames = await instance.getAddressToNames.call(accounts[1]);
            assert.equal(addrForName[0], accounts[1]);
            assert.equal(nameForAddr, my_wallet_name);
            assert.equal(getAddressToNames.indexOf(my_wallet_name), addrForName[1]);
            assert.equal(getAddressToNames.length, 2);
        } catch (e) {
            console.log(e);
            assert.equal(true, false)
        }
    });

    it("Owner should get tfuel", async () => {
        try {
            const instance = await addressName.deployed();
            const balance = fromWei(await web3.eth.getBalance(accounts[0]));
            await instance.assignNewName(my_wallet_name + '2', accounts[1], {
                from: accounts[1],
                value: toWei(newTfuelPrice)
            });
            const newBalance = fromWei(await web3.eth.getBalance(accounts[0]));
            assert.equal(approxeq(newBalance - balance, newTfuelPrice), true);
        } catch (e) {
            console.log(e);
            assert.equal(true, false)
        }
    });


    it("should not allow to get same name", async () => {
        try {
            const instance = await addressName.deployed();
            await instance.assignNewName(my_wallet_name, accounts[1], {from: accounts[1], value: toWei(newTfuelPrice)});
        } catch (e) {
            assert.equal(true, true)
        }
    });


    it("should make new offer", async () => {
        try {
            const instance = await addressName.deployed();
            const msg = await instance.makeOffer(my_wallet_name, {from: accounts[2], value: offerAmount});
            const offerId = msg.receipt.logs[0].args.offerId;
            const offer = await instance.offersForName.call(my_wallet_name, offerId)
            assert.equal(offerId, 1);
            assert.equal(offer[0], offerAmount);
            assert.equal(offer[1], accounts[2]);
        } catch (e) {
            assert.equal(true, false)
        }
    });

    it("should not allow price <1 offers", async () => {
        try {
            const offerAmount = toWei("0.5")
            const instance = await addressName.deployed();
            await instance.makeOffer(my_wallet_name, {from: accounts[2], value: offerAmount});
            assert.equal(true, false);
        } catch (e) {
            assert.equal(true, true)
        }
    });

    it("should not allow offers for names that are not taken", async () => {
        try {
            const instance = await addressName.deployed();
            await instance.makeOffer(my_wallet_name + "__", {from: accounts[2], value: offerAmount});
            assert.equal(true, false);
        } catch (e) {
            assert.equal(true, true)
        }
    });

    it("should be able to cancel offer", async () => {
        try {
            const instance = await addressName.deployed();
            const balance = fromWei(await web3.eth.getBalance(accounts[2]));
            await instance.cancelOffer(my_wallet_name, 1, {from: accounts[2]});
            const newBalance = fromWei(await web3.eth.getBalance(accounts[2]));
            assert.equal(approxeq(newBalance - balance, offerAmount), true);
        } catch (e) {
            assert.equal(true, true)
        }
    });

    it("should not be able to cancel offer if not exists", async () => {
        try {
            const instance = await addressName.deployed();
            await instance.cancelOffer(my_wallet_name, 1, {from: accounts[2]});
            assert.equal(true, false);
        } catch (e) {
            assert.equal(true, true)
        }
    });

    it("should not be able to cancel offer if not owner", async () => {
        try {
            const instance = await addressName.deployed();
            const msg = await instance.makeOffer(my_wallet_name, {from: accounts[2], value: offerAmount});
            const offer_id = msg.logs[0].args.offerId;
            await instance.cancelOffer(my_wallet_name, offer_id, {from: accounts[0]});
            assert.equal(true, false);
        } catch (e) {
            assert.equal(true, true)
        }
    });

    it("should reject offer", async () => {
        try {
            const instance = await addressName.deployed();
            const msg = await instance.makeOffer(my_wallet_name, {from: accounts[2], value: offerAmount});
            const offer_id = msg.logs[0].args.offerId;
            await instance.rejectOffer(my_wallet_name, offer_id, {from: accounts[1]});
            const offer = await instance.offersForName(my_wallet_name, offer_id);
            assert.equal(offer.walletMakingOffer, null_wallet);
        } catch (e) {
            assert.equal(true, false)
        }
    })

    it("should not reject offer if not owner of domain", async () => {
        try {
            const instance = await addressName.deployed();
            const msg = await instance.makeOffer(my_wallet_name, {from: accounts[2], value: offerAmount});
            const offer_id = msg.logs[0].args.offerId;
            await instance.rejectOffer(my_wallet_name, offer_id, {from: accounts[2]});
            assert.equal(true, false);
        } catch (e) {
            assert.equal(true, true)
        }
    })

    it("should be able to accept offer", async () => {
        try {
            const instance = await addressName.deployed();

            const balance_before_contract_owner = fromWei(await web3.eth.getBalance(accounts[0]));
            const balance_before_name_owner = fromWei(await web3.eth.getBalance(accounts[1]));
            const balance_before_acquirer = fromWei(await web3.eth.getBalance(accounts[2]));

            const msg = await instance.makeOffer(my_wallet_name, {from: accounts[2], value: offerAmount});
            const offer_id = msg.logs[0].args.offerId;
            await instance.acceptOffer(my_wallet_name, offer_id, {from: accounts[1]});
            const offer = await instance.offersForName(my_wallet_name, offer_id);

            const domains_for_account_1 = await instance.getAddressToNames(accounts[1]);
            const domains_for_account_2 = await instance.getAddressToNames(accounts[2]);
            const new_address = await instance.nameToAddress(my_wallet_name);

            const balance_after_contract_owner = fromWei(await web3.eth.getBalance(accounts[0]));
            const balance_after_name_owner = fromWei(await web3.eth.getBalance(accounts[1]));
            const balance_after_acquirer = fromWei(await web3.eth.getBalance(accounts[2]));

            assert.equal(domains_for_account_1.indexOf(my_wallet_name), -1);
            assert.notEqual(domains_for_account_2.indexOf(my_wallet_name), -1);
            assert.equal(new_address.ownerAddr, accounts[2]);

            assert.equal(approxeq(balance_after_contract_owner - balance_before_contract_owner, fromWei(offerAmount) / 10), true);
            assert.equal(approxeq(balance_after_name_owner - balance_before_name_owner, fromWei(offerAmount) / 10 * 9), true);
            assert.equal(approxeq(balance_before_acquirer - balance_after_acquirer, fromWei(offerAmount)), true);

            assert.equal(offer.offerAmount, 0);
            assert.equal(offer.walletMakingOffer, null_wallet);
        } catch (e) {
            console.log(e);
            assert.equal(true, false);
        }
    });

});



