const ThetaboardMarketplace = artifacts.require('ThetaboardMarketplace');


module.exports = async function(_deployer) {
  // Use deployer to state migration tasks.
    await _deployer.deploy(ThetaboardMarketplace);
};
