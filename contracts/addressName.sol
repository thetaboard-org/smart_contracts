// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;


contract addressName {

    address payable owner;

    uint public tfuelPrice = 5 ether;

    struct offer {
        uint offerAmount;
        address payable walletMakingOffer;
    }

    struct nameOwner {
        address payable ownerAddr;
        uint indexInAddressToNames;
    }

    mapping(string => nameOwner) public nameToAddress;
    mapping(address => string[]) public addressToNames;

    mapping(string => mapping(uint => offer)) public offersForName;
    mapping(string => uint) private maxOfferIds;

    event offerMade(uint offerId);

    constructor() {
        owner = payable(msg.sender);
    }

    function getAddressToNames(address payable walletAddr) external view returns (string[] memory){
        return addressToNames[walletAddr];
    }

    function setTfuelPrice(uint newPrice) external {
        require(msg.sender == owner);
        tfuelPrice = newPrice;
    }

    function assignNewName(string calldata name, address payable walletAddr) payable external {
        //  make sure the name is not already used, and amount sent is the same as price
        require(nameToAddress[name].ownerAddr == address(0), "Name is already in use");
        require(msg.value == tfuelPrice, "Incorrect amount sent");
        addressToNames[walletAddr].push(name);
        uint index = addressToNames[walletAddr].length - 1;
        nameToAddress[name] = nameOwner(walletAddr, index);
        owner.transfer(msg.value);
    }

    function makeOffer(string calldata name) payable external {
        // make sure the name is used
        require(nameToAddress[name].ownerAddr != address(0), "This name is not currently used");
        require(msg.value > 1 ether, "Offer should be of at least 1 tfuel ");
        offer memory newOffer = offer(msg.value, payable(msg.sender));
        uint offerId = maxOfferIds[name] + 1;
        offersForName[name][offerId] = newOffer;
        maxOfferIds[name] = offerId;
        emit offerMade(offerId);
    }

    function cancelOffer(string calldata name, uint offerId) external {
        offer memory currentOffer = offersForName[name][offerId];
        // make sure offer exists, and was done by the wallet calling this function
        require(currentOffer.offerAmount != 0, "Offer doesn't exists");
        require(currentOffer.walletMakingOffer == msg.sender, "Only owner of offer can cancel it");
        currentOffer.walletMakingOffer.transfer(currentOffer.offerAmount);
        delete (offersForName[name][offerId]);
    }

    function acceptOffer(string calldata name, uint offerId) external {
        offer memory currentOffer = offersForName[name][offerId];
        // make sure offer exists, and owner of name is the wallet calling this function
        require(currentOffer.offerAmount != 0, "Offer doesn't exists");
        require(nameToAddress[name].ownerAddr == msg.sender, "Only owner of name can accept offer");

        // transfer ownership
        delete addressToNames[msg.sender][nameToAddress[name].indexInAddressToNames];
        addressToNames[currentOffer.walletMakingOffer].push(name);
        uint index = addressToNames[currentOffer.walletMakingOffer].length - 1;
        nameToAddress[name] = nameOwner(currentOffer.walletMakingOffer, index);

        // make payments
        uint transferToSender = currentOffer.offerAmount / 10 * 9;
        uint transferToContractOwner = currentOffer.offerAmount / 10;
        require(transferToSender + transferToContractOwner == currentOffer.offerAmount, "bug!");
        payable(msg.sender).transfer(transferToSender);
        owner.transfer(transferToContractOwner);

        // delete offer
        delete (offersForName[name][offerId]);

    }
}