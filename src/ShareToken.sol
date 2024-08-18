// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {IIRM} from "./interfaces/IIRM.sol";
import {IProxyToken} from "./interfaces/IProxyToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Wrapper} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

import "forge-std/console.sol";

contract ShareToken is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public liquidAsset;
    address public interestRateModel;
    address public oracle;
    uint96 public lastUpdateBlockNumber;
    uint256 public debtShare = 1e9;
    uint256 public debtTotal;
    uint16 public ltv = 80;

    mapping(address => bool) public isCollateral;
    mapping(address user => mapping(address collateral => uint256)) public liquidityDebt;
    mapping(address user => mapping(address collateral => uint256)) public fixedDebtShare;
    mapping(address user => mapping(address collateral => uint256)) public variableDebtShare;
    mapping(address collateralAddress => mapping(address user => uint256 amount)) public collaterals;

    event Deposit(address indexed user, address indexed collateralAddress, uint256 amount);
    event Borrow(address indexed user, address indexed collateralAddress, uint256 amount);

    constructor(string memory name_, string memory symbol_, ERC20Wrapper underlyingToken, address owner)
        ERC4626(underlyingToken)
        ERC20(name_, symbol_)
        Ownable(owner)
    {
        lastUpdateBlockNumber = uint96(block.number);
        liquidAsset = underlyingToken.underlying();
        liquidAsset.approve(address(underlyingToken), type(uint256).max);
    }

    function setCollateral(address collateralAddress, bool flag) external onlyOwner {
        isCollateral[collateralAddress] = flag;
    }

    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function setLtv(uint16 _ltv) external onlyOwner {
        ltv = _ltv;
    }

    function setInterestRateModel(address _interestRateModel) external onlyOwner {
        interestRateModel = _interestRateModel;
    }

    function depositCollateral(address user, address collateralAddress, uint256 amount) external {
        updateDebt();
        require(isCollateral[collateralAddress], "Not collateral");
        collaterals[collateralAddress][user] += amount;

        IERC20(collateralAddress).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(user, collateralAddress, amount);
    }

    function isLiquidable(address user, address collateralAddress, uint256 amount) public view returns (bool) {
        uint256 debt = 0;
        if (fixedDebtShare[collateralAddress][user] != 0) {
            debt = getUserDebt(collateralAddress, user);
        }

        uint256 maxBorrow =
            IOracle(oracle).getQuote(collaterals[collateralAddress][user] * ltv / 100, collateralAddress, asset());

        return maxBorrow < (amount + debt);
    }

    function borrow(address collateralAddress, uint256 amount) external {
        require(amount < liquidAsset.balanceOf(asset()), "Amount too large");
        updateDebt();
        require(isCollateral[collateralAddress], "Not collateral");
        require(!isLiquidable(msg.sender, collateralAddress, amount), "Collateral Not Enough");

        IProxyToken(asset()).withdrawUnderlyingToken(msg.sender, amount);

        fixedDebtShare[collateralAddress][msg.sender] += amount;
        liquidityDebt[collateralAddress][msg.sender] += amount;
        variableDebtShare[collateralAddress][msg.sender] = debtShare;

        emit Borrow(msg.sender, collateralAddress, amount);
    }

    function repay(address user, address collateralAddress, uint256 amount) external {
        updateDebt();
        uint256 userDebt = getUserDebt(collateralAddress, user);
        variableDebtShare[collateralAddress][user] = debtShare;

        if (amount > userDebt) {
            fixedDebtShare[collateralAddress][user] = 0;
        } else {
            fixedDebtShare[collateralAddress][user] = userDebt - amount;
        }

        if (amount > liquidityDebt[collateralAddress][user]) {
            uint256 repayInterestDebt = amount - liquidityDebt[collateralAddress][user];
            liquidAsset.safeTransferFrom(msg.sender, asset(), liquidityDebt[collateralAddress][user]);
            liquidAsset.safeTransferFrom(msg.sender, address(this), repayInterestDebt);
            ERC20Wrapper(asset()).depositFor(address(this), repayInterestDebt);
        } else {
            liquidityDebt[collateralAddress][user] -= amount;
            liquidAsset.safeTransferFrom(msg.sender, asset(), amount);
        }
    }

    function liquidate(address user, address collateralAddress) external {
        updateDebt();

        require(isLiquidable(user, collateralAddress, 0), "Not liquidable");

        uint256 userDebt = getUserDebt(collateralAddress, user);
        uint256 repayInterestDebt = userDebt - liquidityDebt[collateralAddress][user];

        liquidAsset.safeTransferFrom(msg.sender, asset(), liquidityDebt[collateralAddress][user]);
        liquidAsset.safeTransferFrom(msg.sender, address(this), repayInterestDebt);
        ERC20Wrapper(asset()).depositFor(address(this), repayInterestDebt);
        IERC20(collateralAddress).safeTransfer(msg.sender, collaterals[collateralAddress][user]);

        fixedDebtShare[collateralAddress][user] = 0;
        liquidityDebt[collateralAddress][user] = 0;
        collaterals[collateralAddress][user] = 0;
    }

    function getUserDebt(address collateralAddress, address user) public view returns (uint256) {
        uint256 newDebtShare = _getNewDebtShare();
        return fixedDebtShare[collateralAddress][user] * newDebtShare / variableDebtShare[collateralAddress][user];
    }

    function _getNewDebtShare() internal view returns (uint256) {
        uint256 blockNumberInternal = (block.number - lastUpdateBlockNumber) / 21;
        uint256 nowRate = IIRM(interestRateModel).computeInterestRate(address(this), totalAssets(), debtTotal);

        return debtShare * (1e9 + blockNumberInternal * nowRate) / 1e9;
    }

    function updateDebt() public {
        debtShare = _getNewDebtShare();
        lastUpdateBlockNumber = uint96(block.number);
    }
}
