// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interface/IPayoutVault.sol";

/// @title PayoutVault
/// @notice Holds the payout-reserve share of plan purchases and executes approved trader payouts.
/// @dev Business split rules stay in the backend. This contract only enforces custody and payout safety.
///      DEFAULT_ADMIN_ROLE can grant any role and drain funds via `emergencyWithdraw`. In production,
///      this role MUST be assigned to a Timelock-governed multisig so role grants and emergency sweeps
///      cannot happen faster than the operational response window. ALLOCATOR_ROLE / PAYOUT_OPERATOR_ROLE
///      SHOULD be held by backend hot wallets with per-token rolling payout caps configured via
///      `setPayoutLimit` to bound the blast radius of a hot-key compromise.
contract PayoutVault is IPayoutVault, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");
    bytes32 public constant PAYOUT_OPERATOR_ROLE = keccak256("PAYOUT_OPERATOR_ROLE");
    bytes32 public constant PAYOUT_PAUSER_ROLE = keccak256("PAYOUT_PAUSER_ROLE");

    mapping(address => bool) private payoutTokens;

    mapping(bytes32 => bool) public processedDepositIds;
    mapping(bytes32 => bool) public processedPayoutIds;

    mapping(address => uint256) public totalReceived;
    mapping(address => uint256) public totalPaidOut;
    mapping(address => uint256) public totalEmergencyWithdrawn;

    /// @notice Per-token balance allowed to remain when disabling support (protects delisting from dust grief).
    mapping(address => uint256) public dustThreshold;

    struct PayoutLimit {
        uint256 cap;          // 0 disables the limit
        uint256 window;       // rolling window duration in seconds
        uint256 windowStart;  // timestamp of current window start
        uint256 spent;        // amount paid out within the current window
    }
    /// @notice Per-token rolling-window payout cap. `cap == 0` means unlimited.
    mapping(address => PayoutLimit) public payoutLimits;

    error InvalidAdmin();
    error InvalidToken();
    error InvalidAmount();
    error InvalidRecipient();
    error UnsupportedToken();
    error DepositAlreadyProcessed();
    error PayoutAlreadyProcessed();
    error TokenHasBalance();
    error InsufficientRecordedReserve();
    error InsufficientVaultBalance();
    error NativeTokenNotSupported();
    error PayoutCapExceeded();
    error NativeWithdrawFailed();
    error InvalidPayoutLimit();

    constructor(address admin, address allocator, address payoutOperator, address[] memory initialTokens) {
        if (admin == address(0)) revert InvalidAdmin();
        if (allocator == address(0)) revert InvalidAdmin();
        if (payoutOperator == address(0)) revert InvalidAdmin();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ALLOCATOR_ROLE, allocator);
        _grantRole(PAYOUT_OPERATOR_ROLE, payoutOperator);
        _grantRole(PAYOUT_PAUSER_ROLE, admin);

        for (uint256 i = 0; i < initialTokens.length; i++) {
            _setPayoutTokenSupport(initialTokens[i], true);
        }
    }

    /// @notice Deposit payout-reserve funds from the allocator wallet.
    /// @dev The backend must calculate the 50% reserve amount and pass a unique depositId.
    function depositReserve(address token, uint256 amount, bytes32 depositId)
        external
        nonReentrant
        whenNotPaused
        onlyRole(ALLOCATOR_ROLE)
    {
        _requirePayoutToken(token);
        if (amount == 0) revert InvalidAmount();
        if (depositId == bytes32(0)) revert InvalidAmount();
        if (processedDepositIds[depositId]) revert DepositAlreadyProcessed();

        processedDepositIds[depositId] = true;

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balanceBefore;

        if (received != amount) revert InvalidAmount();

        totalReceived[token] += received;

        emit ReserveDeposited(depositId, token, msg.sender, received);
    }

    /// @notice Execute an approved trader payout.
    /// @dev The backend must validate the payout request before calling this function.
    function executePayout(address token, address recipient, uint256 amount, bytes32 payoutId)
        external
        nonReentrant
        whenNotPaused
        onlyRole(PAYOUT_OPERATOR_ROLE)
    {
        _requirePayoutToken(token);
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        if (payoutId == bytes32(0)) revert InvalidAmount();
        if (processedPayoutIds[payoutId]) revert PayoutAlreadyProcessed();

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (availableReserve(token) < amount) revert InsufficientRecordedReserve();
        if (balance < amount) revert InsufficientVaultBalance();

        _consumePayoutLimit(token, amount);

        processedPayoutIds[payoutId] = true;
        totalPaidOut[token] += amount;

        IERC20(token).safeTransfer(recipient, amount);

        emit PayoutExecuted(payoutId, token, recipient, amount);
    }

    /// @notice Enable or disable an ERC20 token.
    /// @dev A token can be disabled if the current balance is at or below `dustThreshold[token]`.
    function setPayoutTokenSupport(address token, bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert NativeTokenNotSupported();
        if (!enabled && IERC20(token).balanceOf(address(this)) > dustThreshold[token]) revert TokenHasBalance();
        _setPayoutTokenSupport(token, enabled);
    }

    /// @notice Set the dust balance tolerated when disabling a token.
    /// @dev Protects delisting from being grief-blocked by unsolicited dust donations.
    function setDustThreshold(address token, uint256 threshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert NativeTokenNotSupported();
        dustThreshold[token] = threshold;
        emit DustThresholdSet(token, threshold);
    }

    /// @notice Configure a rolling payout cap for a token.
    /// @dev `cap == 0` disables the limit. When enabled, the window resets every `window` seconds.
    ///      Changing the limit resets the current window counters.
    function setPayoutLimit(address token, uint256 cap, uint256 window) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert NativeTokenNotSupported();
        if (cap > 0 && window == 0) revert InvalidPayoutLimit();

        PayoutLimit storage limit = payoutLimits[token];
        limit.cap = cap;
        limit.window = window;
        limit.windowStart = block.timestamp;
        limit.spent = 0;

        emit PayoutLimitSet(token, cap, window);
    }

    /// @notice Emergency migration path for admin multisig. Only works while paused.
    function emergencyWithdraw(address token, address recipient, uint256 amount)
        external
        nonReentrant
        whenPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (token == address(0)) revert NativeTokenNotSupported();
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < amount) revert InsufficientVaultBalance();

        totalEmergencyWithdrawn[token] += amount;

        IERC20(token).safeTransfer(recipient, amount);

        emit EmergencyWithdraw(token, recipient, amount);
    }

    /// @notice Recover native ETH force-sent via `selfdestruct`. Only works while paused.
    /// @dev `receive()` rejects normal ETH transfers, so any balance is unsolicited.
    function sweepNative(address payable recipient, uint256 amount)
        external
        nonReentrant
        whenPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        if (address(this).balance < amount) revert InsufficientVaultBalance();

        (bool ok,) = recipient.call{value: amount}("");
        if (!ok) revert NativeWithdrawFailed();

        emit NativeWithdrawn(recipient, amount);
    }

    function pausePayoutVault() external onlyRole(PAYOUT_PAUSER_ROLE) {
        _pause();
    }

    function unpausePayoutVault() external onlyRole(PAYOUT_PAUSER_ROLE) {
        _unpause();
    }

    function isPayoutToken(address token) external view returns (bool) {
        return payoutTokens[token];
    }

    function availableReserve(address token) public view returns (uint256) {
        uint256 consumed = totalPaidOut[token] + totalEmergencyWithdrawn[token];
        uint256 received = totalReceived[token];
        return received > consumed ? received - consumed : 0;
    }

    receive() external payable {
        revert NativeTokenNotSupported();
    }

    function _setPayoutTokenSupport(address token, bool enabled) private {
        if (token == address(0)) revert NativeTokenNotSupported();
        if (!Address.isContract(token)) revert InvalidToken();

        payoutTokens[token] = enabled;
        emit PayoutTokenSupportSet(token, enabled);
    }

    function _requirePayoutToken(address token) private view {
        if (token == address(0)) revert NativeTokenNotSupported();
        if (!payoutTokens[token]) revert UnsupportedToken();
    }

    function _consumePayoutLimit(address token, uint256 amount) private {
        PayoutLimit storage limit = payoutLimits[token];
        if (limit.cap == 0) return;

        if (block.timestamp >= limit.windowStart + limit.window) {
            limit.windowStart = block.timestamp;
            limit.spent = 0;
        }

        uint256 newSpent = limit.spent + amount;
        if (newSpent > limit.cap) revert PayoutCapExceeded();
        limit.spent = newSpent;
    }
}
