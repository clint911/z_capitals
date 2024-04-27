 // complete swap functionality -> add recieve,fallback -> cross check accepting swap -> Create Tests to prove functionality -> present
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma abicoder v2;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//Accept cUSD from wallet, Get approval to spend starting with all, swap at determined period on uniswap
/*
  ///FIX: add cUSD interface

  //@assumption: cUSD is readily acceptable as gas
 When trading from a smart contract, the most important thing to keep in mind is that access to an external price source is required. Without this, trades can be frontrun for considerable loss.
 *WARNING: Before executing trade Get Quote from the Ethersjs "server" to prevent being frontrun as described above
 */
contract DollarCostAveraging {
    //errors
    //interfaces, libraries, contracts
    AggregatorV3Interface internal dataFeed;
  // For the scope of these swap examples,
    // we will detail the design considerations when using `exactInput`, `exactInputSingle`, `exactOutput`, and  `exactOutputSingle`.
    // It should be noted that for the sake of these examples we pass in the swap router as a constructor argument instead of inheriting it.
    // More advanced example contracts will detail how to inherit the swap router safely.
    // This example swaps cUSD/wBTC for single path swaps and cUSD/USDC/wBTC for multi path swaps.
    ISwapRouter public immutable swapRouter;

    //Type declarations
    //State variables
    uint24 public constant poolFee = 3000;//lets set a poolFee of  3% for this
    uint256 currSeedNo = block.number; //NOTE: will be replaced once baseline functionality is over
    uint256 public investmentPeriod; //TODO: refactor to use less bytes & to be private
    uint256 public fundingIntervals = 1; //also refactor like above
    uint256 public investmentAmount; //@RefactorLAB
    uint256 public valBTCBought; //value of BTC bought at the end of the period
    uint256 public sumOfValBoughtAtIntervals;
    uint256 public amountToSpendAtEachInterval; //TODO:Will be replaced by a function that uses mathematical optimization techniques to calculate the amount to spend each time based on the current price and past experience as well as the 200 day average and totalAmount for now initialize to a percentage ie 10% for 10 month investment period
    uint256 public currAmountSpent; //TODO: add modules to compare prevAmounts and currAmountSpent and how the number of Bitcoins compare
    uint256 public currBalance; //TODO: refactor to private and add setters and getters
    uint256 public avgNoOfBlocks = 17280 * 30;//avg no of blocks in celo per month
    uint256 public lastBlockNoBoughtAt;
    uint256 public yieldAmount;
    uint256 public currValOfBTCBought;
    uint256 public grossComparativeVal; //diff btwn val that wouldve been bought at the start and the curr total
    uint256 public netComparativeVal; //diff btwn val that wouldve been bought at the start and the total val summed interval
    //TODO: add some neat stuff like calculating mean value bought as well as Standard Deviation for more Data
    address public clientAddr; //depending on  the means of funding chosen, this can be the address that the WBTC will be sent to
    //alfajores BTC/USD address
    address public alfajoresBTCAddr = 0xC0f1567a0037383068B1b269A81B07e76f99710c;

 //NOTE:Asset contract values on uniswap
  address public constant cUSD =0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant wBTC =     0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    //Events
    event boughtWBTC(
        address indexed clientAddr,
        uint currValOfBTCBought,
        uint currAmountSpent
    ); //NOTE: The indexed param enables us to filter the logs using that parameter.

    //Modifiers
    //Functions
    //Layout of Functions
    //constructor
    /*Network: alfajores
     * Aggregator: BTC/USD
     * Address: alfajoresBTCAddr
     */
     /* Initializing the interface within constructor*/
    constructor(ISwapRouter _swapRouter)  {
      swapRouter = _swapRouter;
        dataFeed = AggregatorV3Interface(alfajoresBTCAddr);
    }
    //HACK: to add more functionality  as contract matures
     //TODO: Add the approve function
     /*
       *NOTE:
       The caller must approve the contract to withdraw the tokens from the calling address's account to execute a swap. Remember that because our contract is a contract itself and not an extension of the caller (us); we must also approve the Uniswap protocol router contract to use the tokens that our contract will be in possession of after they have been withdrawn from the calling address (us).
 */

 //FIX: change pool to USDC/WBTC since it has more liquidity to minimize slippage

    /// @notice swapExactInputSingle swaps a fixed amount of cUSD for a maximum possible amount of WBTC
    /// using the cUSD/wBTC 0.3% pool by calling `exactInputSingle` in the swap router.
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its cUSD for this function to succeed.
    /// @param amountIn The exact amount of cUSD that will be swapped for wBTC.
    /// @return amountOut The amount of wBTC received.
    function swapExactInputSingle(uint256 amountIn) external returns (uint256 amountOut) {
        // msg.sender must approve this contract
        //TODO: call the approve function here

        // Transfer the specified amount of cUSD to this contract.
        TransferHelper.safeTransferFrom(cUSD, msg.sender, address(this), amountIn);

        // Approve the router to spend cUSD.
        TransferHelper.safeApprove(cUSD, address(swapRouter), amountIn);
         // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        /*
        * @param {tokenIn} : contract address of the inbound token (cUSD/USDC)
        * @param {tokenOut} : contract address of the outbound token (wBTC)
        * @param {fee} : fee tier of the pool, used to determine the correct pool contract in which to execute the swap
        * @param {recipient} : destination of the outbound token
        * @param {deadline} : unix time after which a swap will fail used to protect it against long-pending transactions and wild price swings
        * @param {amountOutMinimum} : curr set to zero. TODO: calculate using SDK or oracle to protect against an unusually bad price for a trade due to front-running sandwitch or other types of price manipulation
        * @param {sqrtPriceLimitx96} : curr set to zero. TODO: this value can be used to set the limit for the price the swap will push the pool to, which can help protect against price impact or for setting up logic in a variety of price-relevant mechanisms
*/
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: cUSD,
                tokenOut: wBTC,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
    }

/// @notice swapExactOutputSingle swaps a minimum possible amount of cUSD for a fixed amount of WETH.
/// @dev The calling address must approve this contract to spend its cUSD for this function to succeed. As the amount of input cUSD is variable,
/// the calling address will need to approve for a slightly higher amount, anticipating some variance.
/// @param amountOut The exact amount of wBTC to receive from the swap.
/// @param amountInMaximum The amount of cUSD we are willing to spend to receive the specified amount of wBTC.
/// @return amountIn The amount of cUSD actually spent in the swap.

function swapExactOutputSingle(uint256 amountOut, uint256 amountInMaximum) external returns (uint256 amountIn) {
        // Transfer the specified amount of cUSD to this contract.
        TransferHelper.safeTransferFrom(cUSD, msg.sender, address(this), amountInMaximum);

        // Approve the router to spend the specified `amountInMaximum` of cUSD.
        // In production, you should choose the maximum amount to spend based on oracles or other data sources to achieve a better swap.
        TransferHelper.safeApprove(cUSD, address(swapRouter), amountInMaximum);

        ISwapRouter.ExactOutputSingleParams memory params =
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: cUSD,
                tokenOut: wBTC,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
        amountIn = swapRouter.exactOutputSingle(params);

        // For exact output swaps, the amountInMaximum may not have all been spent.
        // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(cUSD, address(swapRouter), 0);
            TransferHelper.safeTransfer(cUSD, msg.sender, amountInMaximum - amountIn);
        }
}
    function deposit () payable external {}
    receive() payable external {}

    //fallback function (if exists)
    //external
    //public
    /* calculates random day to buy by using a random number from 1 - 30 TODO: fix for days with 31 and 29 and 28
     *TODO: will be refactored to utilize the 200 Day moving average and check if value is above provided z-index
     */
     /*Gets BTC/USD price from Oracle */
    function getChainLinkFinalDataFeedLatestAnswer() public pure returns (
      int256 answer
      ) {
        return answer;
    }
    function calculateRandomDayToBuy() public returns (uint256) {}
    //The return value from the function will  be read by the client and used to determine what day it should happen
    function calculateRandomNumber(
        uint256 _currSeedNo
    ) public view returns (uint256) {
        _currSeedNo = currSeedNo;
        uint256 _randVal = uint(keccak256(abi.encodePacked(_currSeedNo)));
        uint256 randVal = _randVal % 10 ^ 2;
        if (randVal > 30) {
            randVal = randVal / 30;
        }
        return randVal;
    }
     function calculateBlockNumber(uint256 _lastBlockNoBoughtAt, uint256 _avgNoOfBlocks) public view {
       _lastBlockNoBoughtAt = lastBlockNoBoughtAt;
       _avgNoOfBlocks = avgNoOfBlocks;
      uint256 currBlockNum = block.number;
      /* 17280 * 30 is the average number of blocks per month:
        * This is one of our buying signals
      *HACK: alter buying signal to reflect 200D MA, using z-score & other values to make it more cost effective
      */
      uint256 blockDifference = currBlockNum - _lastBlockNoBoughtAt;
      //HACK: put a value that exists such that it is way above any average but an indication that not more than a month has passed
        if(blockDifference >= avgNoOfBlocks) {
          //Time to buy baby
          //TODO: call the buying function here

     }
     }
    /* includes functionality to purchase WBTC say from exchange during random day
     *TODO: Refactor to perform checks on which DEXES have the best offers and lower fees and buy from them
     */
   // function calculateBTCAtRandDay() public {}

    /* calculates the sum of the value of BTC bought at each of the intervals: This value is important because it represents the actual value of our purchases at each point of purchase unlike the value at the end which may be subject to volatility value. This will also help ccalculate things like volatility index, standard deviation and other variables
     */
    function calculateSumOfValBoughtAtIntervals() public returns (uint256) {}

    /**TODO:Expose the current value of WBTC bought: okay now that I think about it it would be better off as an event*/
    /*TODO:Fetch Curr Balance left and how many "investment periods left */
    function calculateInvestmentPeriodLeft() public {} //Very obvious functionality

    //internal
    //private
    //view & pure functions
 }

















