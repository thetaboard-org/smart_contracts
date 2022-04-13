const ThetaboardOffer = artifacts.require("ThetaboardOffer");

module.exports = async function (_deployer) {
    // Use deployer to state migration tasks.
    await _deployer.deploy(ThetaboardOffer);
};
