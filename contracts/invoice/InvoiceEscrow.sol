// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title InvoiceEscrow
/// @notice Secure escrow contract for individual invoice payments
/// @dev Deployed per invoice for enhanced security and tracking
contract InvoiceEscrow is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════════════

    /// Invoice details
    string public invoiceId;
    string public invoiceNumber;
    address public seller;
    address public buyer;
    uint256 public totalAmount;
    uint256 public paidAmount;
    uint256 public dueDate;
    bool public isCompleted;
    bool public isCancelled;
    bool public isDisputed;

    /// Payment token
    address public paymentToken;
    uint8 public tokenDecimals;

    /// Payment splits (for multi-recipient invoices)
    struct PaymentSplit {
        address recipient;
        uint256 percentage; // In basis points (10000 = 100%)
        uint256 fixedAmount; // If 0, use percentage
        bool isPrimary;
    }
    PaymentSplit[] public paymentSplits;
    uint256 public totalSplitPercentage;

    /// Dispute resolution
    address public arbiter;
    uint256 public disputeRaisedAt;
    string public disputeReason;

    /// Events
    event PaymentReceived(address indexed payer, uint256 amount, uint256 timestamp);
    event PaymentDistributed(address indexed recipient, uint256 amount);
    event InvoiceCompleted(uint256 timestamp);
    event InvoiceCancelled(uint256 timestamp);
    event DisputeRaised(address indexed raiser, string reason, uint256 timestamp);
    event DisputeResolved(bool sellerFavored, uint256 timestamp);
    event PaymentSplitAdded(address indexed recipient, uint256 percentage, uint256 fixedAmount);

    // ═══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    constructor(
        string memory _invoiceId,
        string memory _invoiceNumber,
        address _seller,
        address _buyer,
        uint256 _totalAmount,
        uint256 _dueDate,
        address _paymentToken,
        address _arbiter
    ) Ownable(msg.sender) {
        require(_seller != address(0), "Invalid seller");
        require(_buyer != address(0), "Invalid buyer");
        require(_totalAmount > 0, "Amount must be > 0");
        require(_dueDate > block.timestamp, "Due date must be in future");

        invoiceId = _invoiceId;
        invoiceNumber = _invoiceNumber;
        seller = _seller;
        buyer = _buyer;
        totalAmount = _totalAmount;
        dueDate = _dueDate;
        paymentToken = _paymentToken;
        arbiter = _arbiter;

        // Get token decimals
        if (_paymentToken != address(0)) {
            tokenDecimals = IERC20Metadata(_paymentToken).decimals();
        } else {
            tokenDecimals = 18; // Native token (ETH, MATIC, etc.)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PAYMENT FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Pay invoice (full or partial)
    /// @param amount Amount to pay
    function pay(uint256 amount) external payable nonReentrant {
        require(!isCompleted, "Invoice already completed");
        require(!isCancelled, "Invoice cancelled");
        require(amount > 0, "Amount must be > 0");
        require(paidAmount + amount <= totalAmount, "Exceeds total amount");

        if (paymentToken == address(0)) {
            // Native token payment
            require(msg.value == amount, "Incorrect ETH amount");
        } else {
            // ERC20 payment
            require(msg.value == 0, "Do not send ETH for token payment");
            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        }

        paidAmount += amount;

        emit PaymentReceived(msg.sender, amount, block.timestamp);

        // Auto-complete if fully paid
        if (paidAmount == totalAmount) {
            _completeInvoice();
        }
    }

    /// @notice Pay full invoice amount
    function payFull() external payable nonReentrant {
        uint256 remaining = totalAmount - paidAmount;
        require(remaining > 0, "Already fully paid");

        if (paymentToken == address(0)) {
            require(msg.value == remaining, "Incorrect ETH amount");
        } else {
            require(msg.value == 0, "Do not send ETH for token payment");
            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), remaining);
        }

        paidAmount = totalAmount;

        emit PaymentReceived(msg.sender, remaining, block.timestamp);

        _completeInvoice();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PAYMENT SPLITS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Add payment split (only owner/factory)
    function addPaymentSplit(
        address recipient,
        uint256 percentage,
        uint256 fixedAmount,
        bool isPrimary
    ) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        require(paymentSplits.length == 0 || !isCompleted, "Cannot modify after completion");

        if (fixedAmount == 0) {
            require(percentage > 0 && percentage <= 10000, "Invalid percentage");
            require(totalSplitPercentage + percentage <= 10000, "Total exceeds 100%");
            totalSplitPercentage += percentage;
        }

        paymentSplits.push(PaymentSplit({
            recipient: recipient,
            percentage: percentage,
            fixedAmount: fixedAmount,
            isPrimary: isPrimary
        }));

        emit PaymentSplitAdded(recipient, percentage, fixedAmount);
    }

    /// @notice Distribute payments to split recipients (public for manual distribution)
    function distributePayments() public nonReentrant {
        require(isCompleted, "Invoice not completed");
        require(paymentSplits.length > 0, "No payment splits");

        uint256 remaining = paidAmount;

        for (uint256 i = 0; i < paymentSplits.length; i++) {
            PaymentSplit memory split = paymentSplits[i];
            uint256 amount;

            if (split.fixedAmount > 0) {
                amount = split.fixedAmount;
            } else {
                amount = (paidAmount * split.percentage) / 10000;
            }

            if (amount > remaining) {
                amount = remaining;
            }

            if (amount > 0) {
                _transferFunds(split.recipient, amount);
                remaining -= amount;
                emit PaymentDistributed(split.recipient, amount);
            }
        }

        // Send any remaining to primary recipient or seller
        if (remaining > 0) {
            address finalRecipient = seller;
            for (uint256 i = 0; i < paymentSplits.length; i++) {
                if (paymentSplits[i].isPrimary) {
                    finalRecipient = paymentSplits[i].recipient;
                    break;
                }
            }
            _transferFunds(finalRecipient, remaining);
            emit PaymentDistributed(finalRecipient, remaining);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // RELEASE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Release funds to seller (only owner after due date or manual release)
    function releaseFunds() external nonReentrant {
        require(isCompleted, "Invoice not completed");
        require(!isDisputed, "Invoice is disputed");
        require(
            msg.sender == owner() || msg.sender == seller || block.timestamp > dueDate + 30 days,
            "Not authorized or too early"
        );

        if (paymentSplits.length > 0) {
            // Use split distribution
            distributePayments();
        } else {
            // Simple release to seller
            _transferFunds(seller, paidAmount);
            emit PaymentDistributed(seller, paidAmount);
        }
    }

    /// @notice Auto-release after grace period
    function autoRelease() external nonReentrant {
        require(isCompleted, "Invoice not completed");
        require(!isDisputed, "Invoice is disputed");
        require(block.timestamp > dueDate + 30 days, "Grace period not elapsed");

        if (paymentSplits.length > 0) {
            distributePayments();
        } else {
            _transferFunds(seller, paidAmount);
            emit PaymentDistributed(seller, paidAmount);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // DISPUTE RESOLUTION
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Raise dispute
    function raiseDispute(string calldata reason) external {
        require(!isCompleted || paidAmount > 0, "Nothing to dispute");
        require(!isCancelled, "Invoice cancelled");
        require(!isDisputed, "Already disputed");
        require(
            msg.sender == seller || msg.sender == buyer,
            "Only parties can dispute"
        );

        isDisputed = true;
        disputeRaisedAt = block.timestamp;
        disputeReason = reason;

        emit DisputeRaised(msg.sender, reason, block.timestamp);
    }

    /// @notice Resolve dispute (only arbiter)
    function resolveDispute(bool sellerFavored) external {
        require(msg.sender == arbiter || msg.sender == owner(), "Only arbiter");
        require(isDisputed, "No active dispute");

        isDisputed = false;

        if (sellerFavored) {
            // Release funds to seller
            if (paymentSplits.length > 0) {
                distributePayments();
            } else {
                _transferFunds(seller, paidAmount);
                emit PaymentDistributed(seller, paidAmount);
            }
        } else {
            // Refund to buyer
            _transferFunds(buyer, paidAmount);
            emit PaymentDistributed(buyer, paidAmount);
        }

        emit DisputeResolved(sellerFavored, block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Cancel invoice (only seller before any payment)
    function cancel() external {
        require(msg.sender == seller || msg.sender == owner(), "Not authorized");
        require(paidAmount == 0, "Cannot cancel after payment");
        require(!isCancelled, "Already cancelled");

        isCancelled = true;

        emit InvoiceCancelled(block.timestamp);
    }

    /// @notice Update arbiter
    function updateArbiter(address newArbiter) external onlyOwner {
        require(newArbiter != address(0), "Invalid arbiter");
        arbiter = newArbiter;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    function _completeInvoice() internal {
        isCompleted = true;
        emit InvoiceCompleted(block.timestamp);
    }

    function _transferFunds(address to, uint256 amount) internal {
        if (paymentToken == address(0)) {
            // Native token
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            // ERC20
            IERC20(paymentToken).safeTransfer(to, amount);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    function getRemainingAmount() external view returns (uint256) {
        return totalAmount - paidAmount;
    }

    function getPaymentProgress() external view returns (uint256) {
        if (totalAmount == 0) return 0;
        return (paidAmount * 10000) / totalAmount; // Basis points
    }

    function isOverdue() external view returns (bool) {
        return block.timestamp > dueDate && !isCompleted;
    }

    function getDaysOverdue() external view returns (uint256) {
        if (block.timestamp <= dueDate || isCompleted) return 0;
        return (block.timestamp - dueDate) / 1 days;
    }

    function getPaymentSplitsCount() external view returns (uint256) {
        return paymentSplits.length;
    }

    function getPaymentSplit(uint256 index) external view returns (
        address recipient,
        uint256 percentage,
        uint256 fixedAmount,
        bool isPrimary
    ) {
        require(index < paymentSplits.length, "Invalid index");
        PaymentSplit memory split = paymentSplits[index];
        return (split.recipient, split.percentage, split.fixedAmount, split.isPrimary);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FALLBACK
    // ═══════════════════════════════════════════════════════════════════════

    receive() external payable {
        revert("Use pay() function");
    }
}
