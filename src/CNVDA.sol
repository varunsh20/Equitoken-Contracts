// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {FunctionsClient} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { Strings } from "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { ERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Pausable } from "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

contract CNVDA is FunctionsClient, ERC20, Pausable {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;

    error NotEnoughCollateral();
    error BelowMinimumRedemption();
    error InvalidDepositAmount();
    error RedemptionFailed();

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);

    enum MintOrRedeem {
        mint,
        redeem
    }

    struct tokenRequest {
        uint256 amountOfToken;
        address requester;
        MintOrRedeem mintOrRedeem;
    }

    uint32 private constant GAS_LIMIT = 200_000;
    uint64 immutable i_subId;


    address private constant s_functionsRouter = 0xC22a79eBA640940ABB6dF0f7982cc119578E11De;
    string s_mintSource;
    string s_redeemSource;

    bytes32 s_donID;
    uint256 s_portfolioBalance;
    uint64 s_secretVersion;
    uint8 s_secretSlot;

    mapping(bytes32 requestId => tokenRequest request) private s_requestIdToRequest;
    mapping(address=>uint256) private userBalance;
    
    address public i_nvdaUsdFeed;
    address public i_usdcUsdFeed;
    address public i_redemptionCoin;
    address public immutable owner;


    uint256 public constant MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT = 50e18;

    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PORTFOLIO_PRECISION = 1e18;
    uint256 public constant COLLATERAL_RATIO = 200; 
    uint256 public constant COLLATERAL_PRECISION = 100;
    uint16 private constant FEES = 3;                // 0.3% fees deduction on every withdraw
    uint16 private constant FEES_PRECISION = 1000;
    uint256 private constant TARGET_DECIMALS = 18;
    uint256 private constant PRECISION = 1e18;

 
    event Response(bytes32 indexed requestId, uint256 character, bytes response, bytes err);


    modifier onlyOwner{
        require(msg.sender==owner,"Only owner");
        _;
    }
 
    constructor(
        uint64 subId,
        string memory mintSource,
        string memory redeemSource,
        bytes32 donId,
        address nvdaPriceFeed,
        address usdcPriceFeed,
        address redemptionCoin,
        uint64 secretVersion,
        uint8 secretSlot
    )
        FunctionsClient(s_functionsRouter)
        ERC20("NVIDIA Token", "CNVDA")
    {
        owner = msg.sender;
        s_mintSource = mintSource;
        s_redeemSource = redeemSource;
        s_donID = donId;
        i_nvdaUsdFeed = nvdaPriceFeed;
        i_usdcUsdFeed = usdcPriceFeed;
        i_subId = subId;
        i_redemptionCoin = redemptionCoin;
        s_secretVersion = secretVersion;
        s_secretSlot = secretSlot;
    }

    function setSecretVersion(uint64 secretVersion) external onlyOwner {
        s_secretVersion = secretVersion;
    }

    function setSecretSlot(uint8 secretSlot) external onlyOwner {
        s_secretSlot = secretSlot;
    }

    function sendMintRequest(uint256 amount)
        external
        whenNotPaused
        returns (bytes32 requestId)
    {
        if(amount<=0){
            revert InvalidDepositAmount(); 
        }
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_mintSource);
        req.addDONHostedSecrets(s_secretSlot, s_secretVersion);
        string[] memory args = new string[](1);
        args[0] = amount.toString();
        req.setArgs(args);
        requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, s_donID);
        s_requestIdToRequest[requestId] = tokenRequest(amount*10**10, msg.sender, MintOrRedeem.mint);
        return requestId;
    }
	
    function sendRedeemRequest(uint256 amount) external whenNotPaused returns (bytes32 requestId) {
        uint256 amountTslaInUsdc = getUsdcValueOfUsd(getUsdValueOfNvda(amount));
        if (amountTslaInUsdc < MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT) {
            revert BelowMinimumRedemption();
        }
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_redeemSource); 
        req.addDONHostedSecrets(s_secretSlot, s_secretVersion);
        string[] memory args = new string[](1);
        args[0] = amount.toString();
        req.setArgs(args);
        requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, s_donID);
        s_requestIdToRequest[requestId] = tokenRequest(amount*10**10, msg.sender, MintOrRedeem.redeem);
        _burn(msg.sender, amount*10**10);
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory /* err */
    )
        internal
        override
        whenNotPaused
    {
        if (s_requestIdToRequest[requestId].mintOrRedeem == MintOrRedeem.mint) {
            _mintFulFillRequest(requestId, response);
        } else {
            _redeemFulFillRequest(requestId, response);
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _mintFulFillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 amountOfTokensToMint = s_requestIdToRequest[requestId].amountOfToken;
        s_portfolioBalance = uint256(bytes32(response));

        if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
            revert NotEnoughCollateral();
        }

        if (amountOfTokensToMint != 0) {
            uint256 tokensInUSDC = getUSDCValueofUSD(getUsdValueOfNvda(amountOfTokensToMint));
            ERC20(i_redemptionCoin).transferFrom(s_requestIdToRequest[requestId].requester, address(this), tokensInUSDC);
            userBalance[s_requestIdToRequest[requestId].requester]+=tokensInUSDC;
            _mint(s_requestIdToRequest[requestId].requester, amountOfTokensToMint);
        }
    }

    function _redeemFulFillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 amountTokensWithdraw = s_requestIdToRequest[requestId].amountOfToken;
        if (amountTokensWithdraw != 0) {
            uint256 tokensInUSDC = getUSDCValueofUSD(getUsdValueOfNvda(amountTokensWithdraw));
            uint256 feesDeduction =  (tokensInUSDC*FEES)/FEES_PRECISION;
            uint256 finalAmount = (tokensInUSDC-feesDeduction);
            bool succ = ERC20(i_redemptionCoin).transfer(msg.sender, finalAmount);
            if (!succ) {
                revert RedemptionFailed();
            }
            userBalance[s_requestIdToRequest[requestId].requester]-=tokensInUSDC;
            return;
        }
    }

    function _getCollateralRatioAdjustedTotalBalance(uint256 amountOfTokensToMint) internal view returns (uint256) {
        uint256 calculatedNewTotalValue = getCalculatedNewTotalValue(amountOfTokensToMint);
        return (calculatedNewTotalValue * COLLATERAL_RATIO) / COLLATERAL_PRECISION;
    }

    function getPortfolioBalance() public view returns (uint256) {
        return s_portfolioBalance;
    }

    function getNvdaPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_nvdaUsdFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdcPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_usdcUsdFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdValueOfNvda(uint256 tslaAmount) public view returns (uint256) {
        return (tslaAmount * getNvdaPrice()) / PRECISION;
    }

    function getUSDCValueofUSD(uint256 usdAmount) public view returns(uint256){
        return (getUsdcPrice()*usdAmount)/PRECISION;
    }


    function getUsdcValueOfUsd(uint256 usdAmount) public view returns (uint256) {
        return (usdAmount * PRECISION) / getUsdcPrice();
    }

    function getTotalUsdValue() public view returns (uint256) {
        return (totalSupply() * getNvdaPrice()) / PRECISION;
    }

    function getCalculatedNewTotalValue(uint256 addedNumberOfTsla) public view returns (uint256) {
        return ((totalSupply() + addedNumberOfTsla) * getNvdaPrice()) / PRECISION;
    }

    function getRequest(bytes32 requestId) public view returns (tokenRequest memory) {
        return s_requestIdToRequest[requestId];
    }
}