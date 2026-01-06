// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title InvoiceRegistry
/// @notice On-chain registry for invoice tracking and verification
/// @dev Stores invoice metadata and IPFS/Arweave references
contract InvoiceRegistry is AccessControl, ReentrancyGuard {
    // ═══════════════════════════════════════════════════════════════════════
    // ROLES
    // ═══════════════════════════════════════════════════════════════════════

    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    // ═══════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════

    enum InvoiceStatus {
        Draft,
        Sent,
        Viewed,
        Pending,
        PartiallyPaid,
        Paid,
        Overdue,
        Cancelled,
        Disputed,
        Refunded
    }

    struct InvoiceMetadata {
        string invoiceId;
        string invoiceNumber;
        address seller;
        address buyer;
        uint256 totalAmount;
        uint256 paidAmount;
        uint256 issueDate;
        uint256 dueDate;
        InvoiceStatus status;
        string ipfsCid;
        string arweaveTxId;
        address escrowAddress;
        bool isRecurring;
        bool isFactored;
        bool exists;
    }

    struct InvoicePayment {
        address payer;
        uint256 amount;
        uint256 timestamp;
        string txHash;
        uint256 chainId;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════════════

    /// Mapping of invoice ID to metadata
    mapping(string => InvoiceMetadata) public invoices;

    /// Mapping of invoice ID to payments
    mapping(string => InvoicePayment[]) public invoicePayments;

    /// Mapping of seller to invoice IDs
    mapping(address => string[]) public sellerInvoices;

    /// Mapping of buyer to invoice IDs
    mapping(address => string[]) public buyerInvoices;

    /// Array of all invoice IDs
    string[] public allInvoiceIds;

    /// Mapping for invoice number uniqueness
    mapping(string => bool) public invoiceNumberExists;

    // ═══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════

    event InvoiceRegistered(
        string indexed invoiceId,
        string invoiceNumber,
        address indexed seller,
        address indexed buyer,
        uint256 amount
    );
    event InvoiceUpdated(string indexed invoiceId, InvoiceStatus newStatus);
    event PaymentRecorded(string indexed invoiceId, address payer, uint256 amount);
    event IPFSReferenceAdded(string indexed invoiceId, string ipfsCid);
    event ArweaveReferenceAdded(string indexed invoiceId, string arweaveTxId);
    event EscrowLinked(string indexed invoiceId, address escrowAddress);
    event InvoiceVerified(string indexed invoiceId, address verifier);

    // ═══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRAR_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // REGISTRATION FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Register new invoice
    function registerInvoice(
        string calldata invoiceId,
        string calldata invoiceNumber,
        address seller,
        address buyer,
        uint256 totalAmount,
        uint256 issueDate,
        uint256 dueDate,
        string calldata ipfsCid,
        string calldata arweaveTxId
    ) external onlyRole(REGISTRAR_ROLE) nonReentrant {
        require(bytes(invoiceId).length > 0, "Invalid invoice ID");
        require(!invoices[invoiceId].exists, "Invoice already exists");
        require(seller != address(0), "Invalid seller");
        require(buyer != address(0), "Invalid buyer");
        require(totalAmount > 0, "Amount must be > 0");
        require(!invoiceNumberExists[invoiceNumber], "Invoice number exists");

        invoices[invoiceId] = InvoiceMetadata({
            invoiceId: invoiceId,
            invoiceNumber: invoiceNumber,
            seller: seller,
            buyer: buyer,
            totalAmount: totalAmount,
            paidAmount: 0,
            issueDate: issueDate,
            dueDate: dueDate,
            status: InvoiceStatus.Draft,
            ipfsCid: ipfsCid,
            arweaveTxId: arweaveTxId,
            escrowAddress: address(0),
            isRecurring: false,
            isFactored: false,
            exists: true
        });

        allInvoiceIds.push(invoiceId);
        sellerInvoices[seller].push(invoiceId);
        buyerInvoices[buyer].push(invoiceId);
        invoiceNumberExists[invoiceNumber] = true;

        emit InvoiceRegistered(invoiceId, invoiceNumber, seller, buyer, totalAmount);

        if (bytes(ipfsCid).length > 0) {
            emit IPFSReferenceAdded(invoiceId, ipfsCid);
        }
        if (bytes(arweaveTxId).length > 0) {
            emit ArweaveReferenceAdded(invoiceId, arweaveTxId);
        }
    }

    /// @notice Update invoice status
    function updateInvoiceStatus(
        string calldata invoiceId,
        InvoiceStatus newStatus
    ) external onlyRole(REGISTRAR_ROLE) {
        require(invoices[invoiceId].exists, "Invoice not found");
        invoices[invoiceId].status = newStatus;
        emit InvoiceUpdated(invoiceId, newStatus);
    }

    /// @notice Record payment
    function recordPayment(
        string calldata invoiceId,
        address payer,
        uint256 amount,
        string calldata txHash,
        uint256 chainId
    ) external onlyRole(REGISTRAR_ROLE) {
        require(invoices[invoiceId].exists, "Invoice not found");
        require(amount > 0, "Amount must be > 0");

        InvoiceMetadata storage invoice = invoices[invoiceId];
        invoice.paidAmount += amount;

        invoicePayments[invoiceId].push(InvoicePayment({
            payer: payer,
            amount: amount,
            timestamp: block.timestamp,
            txHash: txHash,
            chainId: chainId
        }));

        // Update status based on payment
        if (invoice.paidAmount >= invoice.totalAmount) {
            invoice.status = InvoiceStatus.Paid;
        } else if (invoice.paidAmount > 0) {
            invoice.status = InvoiceStatus.PartiallyPaid;
        }

        emit PaymentRecorded(invoiceId, payer, amount);
        emit InvoiceUpdated(invoiceId, invoice.status);
    }

    /// @notice Add IPFS reference
    function addIPFSReference(
        string calldata invoiceId,
        string calldata ipfsCid
    ) external onlyRole(REGISTRAR_ROLE) {
        require(invoices[invoiceId].exists, "Invoice not found");
        invoices[invoiceId].ipfsCid = ipfsCid;
        emit IPFSReferenceAdded(invoiceId, ipfsCid);
    }

    /// @notice Add Arweave reference
    function addArweaveReference(
        string calldata invoiceId,
        string calldata arweaveTxId
    ) external onlyRole(REGISTRAR_ROLE) {
        require(invoices[invoiceId].exists, "Invoice not found");
        invoices[invoiceId].arweaveTxId = arweaveTxId;
        emit ArweaveReferenceAdded(invoiceId, arweaveTxId);
    }

    /// @notice Link escrow contract
    function linkEscrow(
        string calldata invoiceId,
        address escrowAddress
    ) external onlyRole(REGISTRAR_ROLE) {
        require(invoices[invoiceId].exists, "Invoice not found");
        require(escrowAddress != address(0), "Invalid escrow address");
        invoices[invoiceId].escrowAddress = escrowAddress;
        emit EscrowLinked(invoiceId, escrowAddress);
    }

    /// @notice Mark invoice as recurring
    function markAsRecurring(
        string calldata invoiceId,
        bool isRecurring
    ) external onlyRole(REGISTRAR_ROLE) {
        require(invoices[invoiceId].exists, "Invoice not found");
        invoices[invoiceId].isRecurring = isRecurring;
    }

    /// @notice Mark invoice as factored
    function markAsFactored(
        string calldata invoiceId,
        bool isFactored
    ) external onlyRole(REGISTRAR_ROLE) {
        require(invoices[invoiceId].exists, "Invoice not found");
        invoices[invoiceId].isFactored = isFactored;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // VERIFICATION
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Verify invoice (for trusted verifiers)
    function verifyInvoice(
        string calldata invoiceId
    ) external onlyRole(VERIFIER_ROLE) {
        require(invoices[invoiceId].exists, "Invoice not found");
        emit InvoiceVerified(invoiceId, msg.sender);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BATCH OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Batch update invoice statuses
    function batchUpdateStatuses(
        string[] calldata invoiceIds,
        InvoiceStatus[] calldata statuses
    ) external onlyRole(REGISTRAR_ROLE) {
        require(invoiceIds.length == statuses.length, "Length mismatch");

        for (uint256 i = 0; i < invoiceIds.length; i++) {
            if (invoices[invoiceIds[i]].exists) {
                invoices[invoiceIds[i]].status = statuses[i];
                emit InvoiceUpdated(invoiceIds[i], statuses[i]);
            }
        }
    }

    /// @notice Batch record payments
    function batchRecordPayments(
        string[] calldata invoiceIds,
        address[] calldata payers,
        uint256[] calldata amounts,
        string[] calldata txHashes,
        uint256[] calldata chainIds
    ) external onlyRole(REGISTRAR_ROLE) {
        require(invoiceIds.length == amounts.length, "Length mismatch");
        require(invoiceIds.length == payers.length, "Length mismatch");

        for (uint256 i = 0; i < invoiceIds.length; i++) {
            if (invoices[invoiceIds[i]].exists && amounts[i] > 0) {
                this.recordPayment(
                    invoiceIds[i],
                    payers[i],
                    amounts[i],
                    txHashes[i],
                    chainIds[i]
                );
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Get invoice metadata
    function getInvoice(string calldata invoiceId) external view returns (InvoiceMetadata memory) {
        require(invoices[invoiceId].exists, "Invoice not found");
        return invoices[invoiceId];
    }

    /// @notice Get invoice payments
    function getInvoicePayments(string calldata invoiceId) external view returns (InvoicePayment[] memory) {
        return invoicePayments[invoiceId];
    }

    /// @notice Get payment count
    function getPaymentCount(string calldata invoiceId) external view returns (uint256) {
        return invoicePayments[invoiceId].length;
    }

    /// @notice Get seller invoices
    function getSellerInvoices(address seller) external view returns (string[] memory) {
        return sellerInvoices[seller];
    }

    /// @notice Get buyer invoices
    function getBuyerInvoices(address buyer) external view returns (string[] memory) {
        return buyerInvoices[buyer];
    }

    /// @notice Get total invoice count
    function getTotalInvoices() external view returns (uint256) {
        return allInvoiceIds.length;
    }

    /// @notice Check if invoice exists
    function invoiceExists(string calldata invoiceId) external view returns (bool) {
        return invoices[invoiceId].exists;
    }

    /// @notice Get invoice by number
    function getInvoiceByNumber(string calldata invoiceNumber) external view returns (InvoiceMetadata memory) {
        for (uint256 i = 0; i < allInvoiceIds.length; i++) {
            InvoiceMetadata memory invoice = invoices[allInvoiceIds[i]];
            if (keccak256(bytes(invoice.invoiceNumber)) == keccak256(bytes(invoiceNumber))) {
                return invoice;
            }
        }
        revert("Invoice not found");
    }

    /// @notice Get invoices by status
    function getInvoicesByStatus(InvoiceStatus status) external view returns (string[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < allInvoiceIds.length; i++) {
            if (invoices[allInvoiceIds[i]].status == status) {
                count++;
            }
        }

        string[] memory result = new string[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allInvoiceIds.length; i++) {
            if (invoices[allInvoiceIds[i]].status == status) {
                result[index] = allInvoiceIds[i];
                index++;
            }
        }

        return result;
    }

    /// @notice Get overdue invoices
    function getOverdueInvoices() external view returns (string[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < allInvoiceIds.length; i++) {
            InvoiceMetadata memory invoice = invoices[allInvoiceIds[i]];
            if (block.timestamp > invoice.dueDate && invoice.status != InvoiceStatus.Paid) {
                count++;
            }
        }

        string[] memory result = new string[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allInvoiceIds.length; i++) {
            InvoiceMetadata memory invoice = invoices[allInvoiceIds[i]];
            if (block.timestamp > invoice.dueDate && invoice.status != InvoiceStatus.Paid) {
                result[index] = allInvoiceIds[i];
                index++;
            }
        }

        return result;
    }

    /// @notice Get platform statistics
    function getStatistics() external view returns (
        uint256 totalInvoices,
        uint256 totalVolume,
        uint256 totalPaid,
        uint256 pendingCount,
        uint256 overdueCount,
        uint256 disputedCount
    ) {
        totalInvoices = allInvoiceIds.length;
        uint256 volume = 0;
        uint256 paid = 0;
        uint256 pending = 0;
        uint256 overdue = 0;
        uint256 disputed = 0;

        for (uint256 i = 0; i < allInvoiceIds.length; i++) {
            InvoiceMetadata memory invoice = invoices[allInvoiceIds[i]];
            volume += invoice.totalAmount;
            paid += invoice.paidAmount;

            if (invoice.status == InvoiceStatus.Pending || invoice.status == InvoiceStatus.PartiallyPaid) {
                pending++;
            }
            if (invoice.status == InvoiceStatus.Disputed) {
                disputed++;
            }
            if (block.timestamp > invoice.dueDate && invoice.status != InvoiceStatus.Paid) {
                overdue++;
            }
        }

        return (totalInvoices, volume, paid, pending, overdue, disputed);
    }
}
