// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IConditionalTokens.sol";
import "./MarketManagerHelper.sol";
import "./FixedProductMarketMaker.sol";

contract SportsMarketManager is Ownable, ReentrancyGuard, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    IERC20 public mtcToken;
    IConditionalTokens public conditionalTokens;
    MarketManagerHelper public helper;

    struct Market {
        uint256 id;
        string name;
        uint256 creationTime;
        uint256 expirationTime;
        bool isResolved;
        bool outcome;
        address creator;
        address fpmm;
        bytes32 conditionId;
        bytes32 oracleRequestId;
    }

    mapping(uint256 => Market) public markets;
    uint256 public nextMarketId;

    address public chainlinkOracle;
    uint256 public chainlinkFee;
    string public opticOddsApi;
    string public opticOddsApiKey;
    AggregatorV3Interface internal sportsDataFeed;

    event MarketCreated(uint256 indexed marketId, string name, address creator, address fpmm);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event DebugEvent(string message, uint256 marketId, string name, uint256 expirationTime);

    constructor(
        IERC20 _mtcToken,
        IConditionalTokens _conditionalTokens,
        address _oracle,
        uint256 _fee,
        string memory _opticOddsApi,
        string memory _opticOddsApiKey,
        MarketManagerHelper _helper
    ) {
        mtcToken = IERC20(_mtcToken);
        conditionalTokens = IConditionalTokens(_conditionalTokens);
        helper = MarketManagerHelper(_helper);
        chainlinkOracle = _oracle;
        chainlinkFee = _fee;
        opticOddsApi = _opticOddsApi;
        opticOddsApiKey = _opticOddsApiKey;
        setChainlinkToken(address(_mtcToken));
        nextMarketId = 1;
    }

    function setSportsDataFeed(address _sportsDataFeed) external onlyOwner {
        sportsDataFeed = AggregatorV3Interface(_sportsDataFeed);
    }

    function setOpticOddsApi(string memory _newApi) external onlyOwner {
        opticOddsApi = _newApi;
    }

   function createMarketFromOracle(
    string memory _name,
    uint256 _expirationTime,
    string memory fixtureId
) public onlyOwner {
    require(bytes(_name).length > 0, "Market name cannot be empty");
    require(_expirationTime > block.timestamp, "Invalid expiration time");

    uint256 outcomeSlotCount = 2;
    bytes32 questionId = keccak256(abi.encode(address(this), nextMarketId, block.timestamp));
    bytes32 conditionId = keccak256(abi.encode(msg.sender, questionId, outcomeSlotCount));

    emit DebugEvent("Creating Market", nextMarketId, _name, _expirationTime);

    address fpmm = address(new FixedProductMarketMaker(
        mtcToken,
        conditionalTokens,
        conditionId, 
        outcomeSlotCount
    ));

    require(fpmm != address(0), "FPMM creation failed");

    uint256 marketId = nextMarketId++;

    markets[marketId] = Market({
        id: marketId,
        name: _name,
        creationTime: block.timestamp,
        expirationTime: _expirationTime,
        isResolved: false,
        outcome: false,
        creator: msg.sender,
        fpmm: fpmm,
        conditionId: conditionId,
        oracleRequestId: bytes32(0)
    });

    emit DebugEvent("Market Created", marketId, markets[marketId].name, markets[marketId].expirationTime);
    emit MarketCreated(marketId, _name, msg.sender, fpmm);
}


 function requestSportsDataFromOpticOdds(uint256 _marketId, string memory gameId) public onlyOwner {
    require(markets[_marketId].expirationTime <= block.timestamp, "Market has not expired yet");
    require(!markets[_marketId].isResolved, "Market already resolved");

    emit DebugEvent("Sending OpticOdds API Request", _marketId, markets[_marketId].name, markets[_marketId].expirationTime);

    Chainlink.Request memory req = buildChainlinkRequest("7b43e049ed4f4766a7417d9a317fb4d5", address(this), this.fulfillGameResult.selector);

    // ✏️ שינוי הנתיב לשליפת הנתונים ממקור תקין ב-OpticOdds
    req.add("get", string(abi.encodePacked(opticOddsApi, "/fixtures/results?sport=basketball&fixture_id=", gameId)));
    req.add("path", "data.0.result.scores.home.total");

    // ✏️ הוספת Authentication דרך Header מתאים
    req.add("headers", string(abi.encodePacked("X-Api-Key: ", opticOddsApiKey)));

    bytes32 requestId = sendChainlinkRequestTo(chainlinkOracle, req, chainlinkFee);
    markets[_marketId].oracleRequestId = requestId;

    emit DebugEvent("Request Sent to OpticOdds", _marketId, "Request ID:", uint256(requestId));
}


   

    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        while (_i != 0) {
            length -= 1;
            bstr[length] = bytes1(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

  function fulfillGameResult(bytes32 _requestId, bool _result) public recordChainlinkFulfillment(_requestId) {
    for (uint256 i = 1; i < nextMarketId; i++) {
        if (markets[i].oracleRequestId == _requestId) {
            require(!markets[i].isResolved, "Market already resolved");
            
            markets[i].isResolved = true;
            markets[i].outcome = _result;

            emit MarketResolved(i, _result);
            return;
        }
    }
    revert("Request ID not found");
}

}