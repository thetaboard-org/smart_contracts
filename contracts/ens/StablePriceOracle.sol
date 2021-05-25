pragma solidity >=0.5.0;


import "@ensdomains/ethregistrar/contracts/PriceOracle.sol";
import "@ensdomains/ethregistrar/contracts/SafeMath.sol";
import "@ensdomains/ethregistrar/contracts/StringUtils.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.1/contracts/ownership/Ownable.sol";

interface AggregatorInterface {
    function latestAnswer() external view returns (int256);
}


// StablePriceOracle sets a price in tfuelWei per seconds based on domain length
contract StablePriceOracle is Ownable, PriceOracle {
    using SafeMath for *;
    using StringUtils for *;

    // Rent in base price per day by length. Element 0 is for 1-length names, and so on.
    uint[] public rentPrices;

    event RentPriceChanged(uint[] prices);

    bytes4 constant private INTERFACE_META_ID = bytes4(keccak256("supportsInterface(bytes4)"));
    bytes4 constant private ORACLE_ID = bytes4(keccak256("price(string,uint256,uint256)") ^ keccak256("premium(string,uint256,uint256)"));

    constructor(uint[] memory _rentPrices) public {
        setPrices(_rentPrices);
    }

    function price(string calldata name, uint expires, uint duration) external view returns(uint) {
        uint len = name.strlen();
        if(len > rentPrices.length) {
            len = rentPrices.length;
        }
        require(len > 0);
        return rentPrices[len - 1].mul(duration);
    }

    /**
     * @dev Sets rent prices.
     * @param _rentPrices The price array. Each element corresponds to a specific
     *                    name length; names longer than the length of the array
     *                    default to the price of the last element. Values are
     *                    in tfuelWei per seconds.
     */
    function setPrices(uint[] memory _rentPrices) public onlyOwner {
        rentPrices = _rentPrices;
        emit RentPriceChanged(_rentPrices);
    }


    function supportsInterface(bytes4 interfaceID) public view returns (bool) {
        return interfaceID == INTERFACE_META_ID || interfaceID == ORACLE_ID;
    }
}
