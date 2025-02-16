// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "./IConditionalTokens.sol";
import "./MarketManagerHelper.sol";
import "./FixedProductMarketMaker.sol";

contract MarketManager is Ownable, ReentrancyGuard, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    IERC20 public mtcToken;
    IConditionalTokens public conditionalTokens;
    MarketManagerHelper public helper;

    uint256 public constant MIN_INITIAL_LIQUIDITY = 10 * 10**18; // 10 MTC נזילות ראשונית

    struct Market {
        uint256 id;
        string name;
        uint256 creationTime;
        uint256 expirationTime;
        bool isResolved;
        address creator;
        address fpmm;
        bytes32 conditionId;
        uint256 initialLiquidity;
        uint256 parentMarketId;
        bool isConditional;
        bool parentCondition;
        bytes32 oracleRequestId;
    }

    mapping(uint256 => Market) public markets;
    uint256 public nextMarketId;

    address public oracle;
    bytes32 public jobId;
    uint256 public fee;

    event MarketCreated(uint256 indexed marketId, string name, address creator, address fpmm);
    event ConditionalMarketCreated(uint256 indexed marketId, string name, address creator, address fpmm, uint256 parentMarketId, bool parentCondition);
    event MarketFunded(uint256 indexed marketId, address funder, uint256 amount);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event MarketCancelled(uint256 indexed marketId, string reason);
    event DebugMarketCreated(uint256 id, string name, uint256 creationTime, uint256 expirationTime, address creator);

    constructor(
        IERC20 _mtcToken,
        IConditionalTokens _conditionalTokens,
        address _oracle,
        MarketManagerHelper _helper
    ) {
        mtcToken = IERC20(_mtcToken);
        conditionalTokens = IConditionalTokens(_conditionalTokens);
        helper = MarketManagerHelper(_helper);
        oracle = _oracle;
        nextMarketId = 1;
        setChainlinkToken(address(_mtcToken));
    }

    modifier marketExists(uint256 _marketId) {
        require(_marketId > 0 && _marketId < nextMarketId, "Market does not exist");
        _;
    }

    modifier marketNotResolved(uint256 _marketId) {
        require(!markets[_marketId].isResolved, "Market already resolved");
        _;
    }

    modifier marketExpired(uint256 _marketId) {
        require(block.timestamp >= markets[_marketId].expirationTime, "Market not expired yet");
        _;
    }

    function createMarket(string memory _name, uint256 _duration) external {
        require(bytes(_name).length > 0, "Market name cannot be empty");
        require(_duration > 0, "Duration must be positive");
        _createMarket(_name, _duration, 0, 0, false, false);
    }

    function createConditionalMarket(string memory _name, uint256 _duration, uint256 _parentMarketId, bool _parentCondition) external {
        require(bytes(_name).length > 0, "Market name cannot be empty");
        require(_duration > 0, "Duration must be positive");
        require(_parentMarketId > 0 && _parentMarketId < nextMarketId, "Invalid parent market");
        require(!markets[_parentMarketId].isResolved, "Parent market already resolved");
        _createMarket(_name, _duration, 0, _parentMarketId, true, _parentCondition);
    }

    function _createMarket(
        string memory _name,
        uint256 _duration,
        uint256 _initialLiquidity,
        uint256 _parentMarketId,
        bool _isConditional,
        bool _parentCondition
    ) internal {
        emit DebugMarketCreated(nextMarketId, _name, block.timestamp, block.timestamp + _duration, msg.sender);

        uint256 liquidityToAdd = _initialLiquidity > 0 ? _initialLiquidity : MIN_INITIAL_LIQUIDITY;

        uint256 marketId = nextMarketId++;
        emit DebugMarketCreated(marketId, " Market ID Assigned", block.timestamp, block.timestamp + _duration, msg.sender);

        bytes32 questionId = keccak256(abi.encodePacked(address(this), marketId, block.timestamp));
        conditionalTokens.prepareCondition(address(this), questionId, 2);
        bytes32 conditionId = conditionalTokens.getConditionId(address(this), questionId, 2);
        emit DebugMarketCreated(marketId, " Condition Created", block.timestamp, block.timestamp + _duration, msg.sender);

        emit DebugMarketCreated(marketId, "Before FPMM Creation", block.timestamp, block.timestamp + _duration, msg.sender);
        FixedProductMarketMaker fpmm = new FixedProductMarketMaker(
            mtcToken,
            conditionalTokens,
            conditionId,
            2
        );
        emit DebugMarketCreated(marketId, "After FPMM Creation", block.timestamp, block.timestamp + _duration, msg.sender);

        require(address(fpmm) != address(0), "Failed to create FPMM");

        if (mtcToken.balanceOf(address(this)) >= liquidityToAdd) {
            require(mtcToken.transfer(address(fpmm), liquidityToAdd), "Failed to transfer initial liquidity");
            fpmm.addLiquidity(liquidityToAdd);
        }

        emit DebugMarketCreated(marketId, " MTC Transferred (if applicable)", block.timestamp, block.timestamp + _duration, msg.sender);

        markets[marketId] = Market({
            id: marketId,
            name: _name,
            creationTime: block.timestamp,
            expirationTime: block.timestamp + _duration,
            isResolved: false,
            creator: msg.sender,
            fpmm: address(fpmm),
            conditionId: conditionId,
            initialLiquidity: liquidityToAdd,
            parentMarketId: _parentMarketId,
            isConditional: _isConditional,
            parentCondition: _parentCondition,
            oracleRequestId: bytes32(0)
        });

        emit DebugMarketCreated(marketId, " Market Saved in Storage", block.timestamp, block.timestamp + _duration, msg.sender);
        emit DebugMarketCreated(nextMarketId, "Entering _createMarket()", block.timestamp, block.timestamp + _duration, msg.sender);
        emit DebugMarketCreated(nextMarketId, _name, block.timestamp, block.timestamp + _duration, msg.sender);
        emit DebugMarketCreated(nextMarketId, " _parentMarketId", _parentMarketId, block.timestamp, msg.sender);
        emit DebugMarketCreated(nextMarketId, " _isConditional", _isConditional ? 1 : 0, block.timestamp, msg.sender);
        emit DebugMarketCreated(nextMarketId, " _initialLiquidity", _initialLiquidity, block.timestamp, msg.sender);

        if (_isConditional) {
            emit ConditionalMarketCreated(marketId, _name, msg.sender, address(fpmm), _parentMarketId, _parentCondition);
        } else {
            emit MarketCreated(marketId, _name, msg.sender, address(fpmm));
        }
    }

    function fundMarket(uint256 _marketId, uint256 _amount) external {
        Market storage market = markets[_marketId];
        require(market.id != 0, "Market does not exist");
        require(!market.isResolved, "Market is already resolved");
        require(_amount > 0, "Funding amount must be greater than 0");

        require(mtcToken.transferFrom(msg.sender, address(this), _amount), "Failed to transfer MTC tokens");
        require(mtcToken.approve(market.fpmm, _amount), "Failed to approve FPMM");

        FixedProductMarketMaker fpmm = FixedProductMarketMaker(market.fpmm);
        fpmm.addLiquidity(_amount);

        emit MarketFunded(_marketId, msg.sender, _amount);
    }

    function requestMarketResolution(uint256 _marketId) external onlyOwner marketExists(_marketId) marketNotResolved(_marketId) marketExpired(_marketId) {
        Market storage market = markets[_marketId];
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfillMarketResolution.selector);
        
        request.add("marketId", helper.uint2str(market.id));
        market.oracleRequestId = sendChainlinkRequestTo(oracle, request, fee);
    }

    function fulfillMarketResolution(bytes32 _requestId, bool _outcome) external recordChainlinkFulfillment(_requestId) {
        for (uint256 i = 1; i < nextMarketId; i++) {
            if (markets[i].oracleRequestId == _requestId) {
                _resolveMarket(i, _outcome);
                return;
            }
        }
        revert("Market not found");
    }

    function _resolveMarket(uint256 _marketId, bool _outcome) internal marketExists(_marketId) marketNotResolved(_marketId) marketExpired(_marketId) {
        Market storage market = markets[_marketId];

        if (market.isConditional) {
            if (markets[market.parentMarketId].parentCondition != _outcome) {
                _cancelMarket(_marketId, "Parent market condition not met");
                return;
            }
        }

        market.isResolved = true;

        uint256[] memory payouts = new uint256[](2);
        payouts[_outcome ? 0 : 1] = 1;
        conditionalTokens.reportPayouts(market.conditionId, payouts);

        emit MarketResolved(_marketId, _outcome);
    }

    function _cancelMarket(uint256 _marketId, string memory _reason) internal {
        Market storage market = markets[_marketId];
        market.isResolved = true;

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1;
        payouts[1] = 1;
        conditionalTokens.reportPayouts(market.conditionId, payouts);

        emit MarketCancelled(_marketId, _reason);
    }

    function addTrustedCreator(address _creator) external onlyOwner {
        // הוספת יוצר מורשה
    }

    function removeTrustedCreator(address _creator) external onlyOwner {
        // הסרת יוצר מורשה
    }

    function setHelperAddress(address _helperAddress) external onlyOwner {
        require(_helperAddress != address(0), "Invalid helper address");
        helper = MarketManagerHelper(_helperAddress);
    }

    function getMarketInfo(uint256 _marketId) external view returns (
        string memory name,
        uint256 creationTime,
        uint256 expirationTime,
        bool isResolved,
        address creator,
        address fpmm,
        uint256 initialLiquidity,
        bool isConditional,
        uint256 parentMarketId
    ) {
        Market storage market = markets[_marketId];
        return (
            market.name,
            market.creationTime,
            market.expirationTime,
            market.isResolved,
            market.creator,
            market.fpmm,
            market.initialLiquidity,
            market.isConditional,
            market.parentMarketId
        );
    }

    function getMarketDetails(uint256 marketId) external view returns (
        string memory name,
        uint256 duration,
        uint256 initialLiquidity,
        bool isResolved
    ) {
        Market storage market = markets[marketId];
        return (market.name, market.expirationTime - market.creationTime, market.initialLiquidity, market.isResolved);
    }

    function getMarketCount() public view returns (uint256) {
        return nextMarketId - 1;
    }
}


