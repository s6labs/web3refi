// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./InvoiceEscrow.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title InvoiceFactory
/// @notice Factory contract for deploying individual invoice escrow contracts
/// @dev Creates and manages invoice escrow contracts
contract InvoiceFactory is Ownable, ReentrancyGuard {
    // ═══════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════════════

    /// Mapping of invoice ID to escrow contract
    mapping(string => address) public invoiceEscrows;

    /// Array of all escrow addresses
    address[] public allEscrows;

    /// Mapping of user to their invoices (as seller)
    mapping(address => address[]) public sellerInvoices;

    /// Mapping of user to their invoices (as buyer)
    mapping(address => address[]) public buyerInvoices;

    /// Default arbiter
    address public defaultArbiter;

    /// Platform fee (in basis points, 100 = 1%)
    uint256 public platformFee;
    address public feeCollector;

    /// Events
    event InvoiceEscrowCreated(
        string indexed invoiceId,
        address indexed escrowAddress,
        address indexed seller,
        address buyer,
        uint256 amount
    );
    event PlatformFeeUpdated(uint256 newFee);
    event FeeCollectorUpdated(address newCollector);
    event DefaultArbiterUpdated(address newArbiter);

    // ═══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    constructor(address _defaultArbiter, address _feeCollector) Ownable(msg.sender) {
        require(_defaultArbiter != address(0), "Invalid arbiter");
        require(_feeCollector != address(0), "Invalid fee collector");

        defaultArbiter = _defaultArbiter;
        feeCollector = _feeCollector;
        platformFee = 50; // 0.5% default
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ESCROW CREATION
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Create new invoice escrow
    function createInvoiceEscrow(
        string calldata invoiceId,
        string calldata invoiceNumber,
        address seller,
        address buyer,
        uint256 totalAmount,
        uint256 dueDate,
        address paymentToken,
        address customArbiter
    ) external nonReentrant returns (address) {
        address arbiter = customArbiter != address(0) ? customArbiter : defaultArbiter;

        return _createEscrowInternal(
            invoiceId,
            invoiceNumber,
            seller,
            buyer,
            totalAmount,
            dueDate,
            paymentToken,
            arbiter
        );
    }

    /// @notice Create invoice with payment splits
    function createInvoiceWithSplits(
        string calldata invoiceId,
        string calldata invoiceNumber,
        address seller,
        address buyer,
        uint256 totalAmount,
        uint256 dueDate,
        address paymentToken,
        address customArbiter,
        address[] calldata splitRecipients,
        uint256[] calldata splitPercentages,
        uint256[] calldata splitFixedAmounts,
        bool[] calldata splitIsPrimary
    ) external nonReentrant returns (address) {
        require(splitRecipients.length == splitPercentages.length, "Length mismatch");
        require(splitRecipients.length == splitFixedAmounts.length, "Length mismatch");
        require(splitRecipients.length == splitIsPrimary.length, "Length mismatch");

        // Create escrow
        address escrowAddress = this.createInvoiceEscrow(
            invoiceId,
            invoiceNumber,
            seller,
            buyer,
            totalAmount,
            dueDate,
            paymentToken,
            customArbiter
        );

        // Add payment splits
        InvoiceEscrow escrow = InvoiceEscrow(payable(escrowAddress));
        for (uint256 i = 0; i < splitRecipients.length; i++) {
            escrow.addPaymentSplit(
                splitRecipients[i],
                splitPercentages[i],
                splitFixedAmounts[i],
                splitIsPrimary[i]
            );
        }

        return escrowAddress;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BATCH OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Create multiple invoices in one transaction
    function batchCreateInvoices(
        string[] calldata invoiceIds,
        string[] calldata invoiceNumbers,
        address[] calldata sellers,
        address[] calldata buyers,
        uint256[] calldata amounts,
        uint256[] calldata dueDates,
        address[] calldata paymentTokens
    ) external nonReentrant returns (address[] memory escrows) {
        uint256 length = invoiceIds.length;
        require(length == sellers.length, "Length mismatch");
        require(length == buyers.length, "Length mismatch");
        require(length == amounts.length, "Length mismatch");
        require(length == dueDates.length, "Length mismatch");

        escrows = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            escrows[i] = _createEscrowInternal(
                invoiceIds[i],
                invoiceNumbers[i],
                sellers[i],
                buyers[i],
                amounts[i],
                dueDates[i],
                paymentTokens[i],
                defaultArbiter
            );
        }
    }

    /// @notice Internal escrow creation to avoid stack too deep
    function _createEscrowInternal(
        string calldata invoiceId,
        string calldata invoiceNumber,
        address seller,
        address buyer,
        uint256 totalAmount,
        uint256 dueDate,
        address paymentToken,
        address arbiter
    ) internal returns (address) {
        require(bytes(invoiceId).length > 0, "Invalid invoice ID");
        require(invoiceEscrows[invoiceId] == address(0), "Invoice already exists");
        require(seller != address(0), "Invalid seller");
        require(buyer != address(0), "Invalid buyer");
        require(totalAmount > 0, "Amount must be > 0");

        // Deploy new escrow
        InvoiceEscrow escrow = new InvoiceEscrow(
            invoiceId,
            invoiceNumber,
            seller,
            buyer,
            totalAmount,
            dueDate,
            paymentToken,
            arbiter
        );

        address escrowAddress = address(escrow);

        // Store escrow
        invoiceEscrows[invoiceId] = escrowAddress;
        allEscrows.push(escrowAddress);
        sellerInvoices[seller].push(escrowAddress);
        buyerInvoices[buyer].push(escrowAddress);

        emit InvoiceEscrowCreated(
            invoiceId,
            escrowAddress,
            seller,
            buyer,
            totalAmount
        );

        return escrowAddress;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Update platform fee
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high (max 10%)");
        platformFee = newFee;
        emit PlatformFeeUpdated(newFee);
    }

    /// @notice Update fee collector
    function updateFeeCollector(address newCollector) external onlyOwner {
        require(newCollector != address(0), "Invalid collector");
        feeCollector = newCollector;
        emit FeeCollectorUpdated(newCollector);
    }

    /// @notice Update default arbiter
    function updateDefaultArbiter(address newArbiter) external onlyOwner {
        require(newArbiter != address(0), "Invalid arbiter");
        defaultArbiter = newArbiter;
        emit DefaultArbiterUpdated(newArbiter);
    }

    /// @notice Emergency pause (for specific escrow)
    function emergencyPauseEscrow(string calldata invoiceId) external onlyOwner {
        address escrowAddress = invoiceEscrows[invoiceId];
        require(escrowAddress != address(0), "Escrow not found");
        // Implementation would require Pausable in InvoiceEscrow
    }

    // ═══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Get escrow address by invoice ID
    function getEscrowByInvoiceId(string calldata invoiceId) external view returns (address) {
        return invoiceEscrows[invoiceId];
    }

    /// @notice Get all escrows for a seller
    function getSellerInvoices(address seller) external view returns (address[] memory) {
        return sellerInvoices[seller];
    }

    /// @notice Get all escrows for a buyer
    function getBuyerInvoices(address buyer) external view returns (address[] memory) {
        return buyerInvoices[buyer];
    }

    /// @notice Get total number of escrows
    function getTotalEscrows() external view returns (uint256) {
        return allEscrows.length;
    }

    /// @notice Get escrow at index
    function getEscrowAtIndex(uint256 index) external view returns (address) {
        require(index < allEscrows.length, "Index out of bounds");
        return allEscrows[index];
    }

    /// @notice Get invoice details from escrow
    function getInvoiceDetails(string calldata invoiceId) external view returns (
        address escrowAddress,
        address seller,
        address buyer,
        uint256 totalAmount,
        uint256 paidAmount,
        uint256 dueDate,
        bool isCompleted,
        bool isCancelled,
        bool isDisputed
    ) {
        escrowAddress = invoiceEscrows[invoiceId];
        require(escrowAddress != address(0), "Escrow not found");

        InvoiceEscrow escrow = InvoiceEscrow(payable(escrowAddress));

        return (
            escrowAddress,
            escrow.seller(),
            escrow.buyer(),
            escrow.totalAmount(),
            escrow.paidAmount(),
            escrow.dueDate(),
            escrow.isCompleted(),
            escrow.isCancelled(),
            escrow.isDisputed()
        );
    }

    /// @notice Check if invoice escrow exists
    function invoiceExists(string calldata invoiceId) external view returns (bool) {
        return invoiceEscrows[invoiceId] != address(0);
    }

    /// @notice Get seller invoice count
    function getSellerInvoiceCount(address seller) external view returns (uint256) {
        return sellerInvoices[seller].length;
    }

    /// @notice Get buyer invoice count
    function getBuyerInvoiceCount(address buyer) external view returns (uint256) {
        return buyerInvoices[buyer].length;
    }

    /// @notice Get platform statistics
    function getPlatformStats() external view returns (
        uint256 totalInvoices,
        uint256 totalVolume,
        uint256 completedInvoices,
        uint256 disputedInvoices
    ) {
        totalInvoices = allEscrows.length;
        uint256 volume = 0;
        uint256 completed = 0;
        uint256 disputed = 0;

        for (uint256 i = 0; i < allEscrows.length; i++) {
            InvoiceEscrow escrow = InvoiceEscrow(payable(allEscrows[i]));
            volume += escrow.totalAmount();
            if (escrow.isCompleted()) completed++;
            if (escrow.isDisputed()) disputed++;
        }

        return (totalInvoices, volume, completed, disputed);
    }
}
