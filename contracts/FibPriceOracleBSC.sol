pragma solidity ^0.8.4;

import "./PriceOracle.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IStdReference {
    /// A structure returned whenever someone requests for standard reference data.
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }

    /// Returns the price data for the given base/quote pair. Revert if not available.
    function getReferenceData(string memory _base, string memory _quote) external view returns (ReferenceData memory);

    /// Similar to getReferenceData, but with multiple base/quote pairs at once.
    function getReferenceDataBulk(string[] memory _bases, string[] memory _quotes) external view returns (ReferenceData[] memory);
}

contract FibPriceOracleBSC is PriceOracle {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address public admin;

    IStdReference ref;
    address public wrapped = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    struct PriceInfo {
        address token;              // Address of token contract, TOKEN
        address baseToken;          // Address of base token contract, BASETOKEN
        address lpToken;            // Address of TOKEN-BASETOKEN pair contract
        bool active;                // Active status of price record 0 
    }

    mapping(address => PriceInfo) public priceRecords;
    
    event NewAdmin(address oldAdmin, address newAdmin);
    event PriceRecordUpdated(address token, address baseToken, address lpToken, bool _active);

    constructor(IStdReference _ref) {
        ref = _ref;
        admin = msg.sender;
    }

    function getTokenPrice(address _tokenAddress) public view override returns (uint256) {
        IERC20 token = IERC20(_tokenAddress);
        IStdReference.ReferenceData memory data = ref.getReferenceData(token.symbol(), "USD");
        uint256 price = data.rate;
        uint256 decimalDelta = 18-uint256(token.decimals());
        return price.mul(10**decimalDelta);
    }

    function getPriceFromDex(address _tokenAddress) public view returns (uint256) {
        PriceInfo storage priceInfo = priceRecords[_tokenAddress];
        if (priceInfo.active) {
            return 1;
        } else {
            return 0;
        }
    }

    function getPriceFromOracle(address _tokenAddress) public view returns (uint256) {
        IERC20 token = IERC20(_tokenAddress);
        try ref.getReferenceData(token.symbol(), "USD") returns (IStdReference.ReferenceData memory data){
            uint256 price = data.rate;
            uint256 decimalDelta = 18-uint256(token.decimals());
            return price.mul(10**decimalDelta);            
        } catch {
            return 0;
        }
    }

    function setDexPriceInfo(address _token, address _baseToken, address _lpToken, bool _active) public {
        require(msg.sender == admin, "only admin can set DEX price");
        PriceInfo storage priceInfo = priceRecords[_token];
        require(priceInfo.active == false, "price record already listed");
        uint256 baseTokenPrice = getPriceFromOracle(_baseToken);
        require(baseTokenPrice > 0, "invalid base token");
        priceInfo.token = _token;
        priceInfo.baseToken = _baseToken;
        priceInfo.lpToken = _lpToken;
        priceInfo.active = _active;
        emit PriceRecordUpdated(_token, _baseToken, _lpToken, _active);
    }

    function setAdmin(address newAdmin) external {
        require(msg.sender == admin, "only admin can set new admin");
        address oldAdmin = admin;
        admin = newAdmin;

        emit NewAdmin(oldAdmin, newAdmin);
    }    


}