// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "./IConditionalTokens.sol";
import "./MarketManagerHelper.sol";
import "./FixedProductMarketMaker.sol";

contract MarketManager is Ownable, ReentrancyGuard, ChainlinkClient, ERC1155Holder {
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

        uint256 outcomeSlotCount = 2;
        bytes32 questionId = keccak256(abi.encode(address(this), nextMarketId, block.timestamp));
        bytes32 conditionId = keccak256(abi.encode(msg.sender, questionId, outcomeSlotCount));

        emit DebugMarketCreated(nextMarketId, "Before Condition ID Creation", block.timestamp, block.timestamp + _duration, msg.sender);
        
        require(conditionId != bytes32(0), "Invalid conditionId");

        emit DebugMarketCreated(nextMarketId, "Before FPMM Creation", block.timestamp, block.timestamp + _duration, msg.sender);

        require(address(mtcToken) != address(0), "MTC Token address is invalid");
        require(address(conditionalTokens) != address(0), "ConditionalTokens address is invalid");

        address fpmm = address(new FixedProductMarketMaker(
            mtcToken,
            conditionalTokens,
            conditionId, 
            outcomeSlotCount
        ));

        require(fpmm != address(0), "FPMM creation failed");

        emit DebugMarketCreated(nextMarketId, "FPMM Created", block.timestamp, block.timestamp + _duration, fpmm);

        uint256 marketId = nextMarketId++;
        markets[marketId] = Market({
            id: marketId,
            name: _name,
            creationTime: block.timestamp,
            expirationTime: block.timestamp + _duration,
            isResolved: false,
            creator: msg.sender,
            fpmm: fpmm,
            conditionId: conditionId,
            initialLiquidity: MIN_INITIAL_LIQUIDITY,
            parentMarketId: 0,
            isConditional: false,
            parentCondition: false,
            oracleRequestId: bytes32(0)
        });

        emit DebugMarketCreated(nextMarketId, "After Market Struct Update", block.timestamp, block.timestamp + _duration, msg.sender);
        emit MarketCreated(marketId, _name, msg.sender, fpmm);
    }

    function createFPMM(uint256 _marketId) external {
        require(markets[_marketId].id == _marketId, "Market does not exist");
        require(markets[_marketId].fpmm == address(0), "FPMM already created");

        uint256 outcomeSlotCount = 2;
        bytes32 questionId = keccak256(abi.encode(address(this), _marketId, block.timestamp));
        bytes32 conditionId = keccak256(abi.encode(msg.sender, questionId, outcomeSlotCount));

        require(conditionId != bytes32(0), "Invalid conditionId");

        address fpmm = address(new FixedProductMarketMaker(
            mtcToken,
            conditionalTokens,
            conditionId, 
            outcomeSlotCount
        ));

        require(fpmm != address(0), "FPMM creation failed");

        emit DebugMarketCreated(_marketId, "FPMM Created", block.timestamp, block.timestamp + 86400, fpmm);

        markets[_marketId].fpmm = fpmm;
        markets[_marketId].conditionId = conditionId;

        emit DebugMarketCreated(_marketId, "FPMM Saved in Market", block.timestamp, block.timestamp + 86400, markets[_marketId].fpmm);
    }

    // ✅ תיקון תאימות לפונקציות ERC1155Receiver
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    // ✅ פונקציה להעברת טוקנים מהחוזה
    function redeemPositions(address token, uint256 positionId, uint256 amount) external onlyOwner {
        IERC1155(token).safeTransferFrom(address(this), msg.sender, positionId, amount, "");
    }
}




