const ThetaboardCreatorManager = artifacts.require("ThetaboardCreatorManager");

module.exports = async function (_deployer) {
    // Use deployer to state migration tasks.
    await _deployer.deploy(ThetaboardCreatorManager);
};
