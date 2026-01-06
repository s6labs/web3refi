// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title UniversalRegistry
 * @dev Universal name registry for any blockchain
 *
 * This contract provides a simple, gas-efficient name registration system
 * that can be deployed on any EVM-compatible chain to enable name services.
 *
 * Features:
 * - Domain registration with expiration
 * - Resolver management
 * - Owner management
 * - Grace period support
 * - Transfer/renewal functionality
 *
 * Compatible with ENS architecture for easy integration.
 */
contract UniversalRegistry {

    // ══════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════

    struct Record {
        address owner;
        address resolver;
        uint64 expiry;
    }

    // ══════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ══════════════════════════════════════════════════════════════════════

    /// Top-level domain (e.g., "xdc", "hedera")
    string public tld;

    /// Registry owner (can add controllers)
    address public registryOwner;

    /// Namehash of the TLD (e.g., namehash("xdc"))
    bytes32 public tldNode;

    /// Grace period after expiration (default: 90 days)
    uint256 public constant GRACE_PERIOD = 90 days;

    /// Minimum registration duration (default: 28 days)
    uint256 public constant MIN_REGISTRATION_DURATION = 28 days;

    /// Records: namehash → Record
    mapping(bytes32 => Record) public records;

    /// Controllers: address → bool (can register names)
    mapping(address => bool) public controllers;

    // ══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════

    event NameRegistered(
        bytes32 indexed node,
        string name,
        address indexed owner,
        uint256 expires
    );

    event NameRenewed(
        bytes32 indexed node,
        uint256 expires
    );

    event Transfer(
        bytes32 indexed node,
        address indexed newOwner
    );

    event NewResolver(
        bytes32 indexed node,
        address resolver
    );

    event ControllerAdded(address indexed controller);
    event ControllerRemoved(address indexed controller);

    // ══════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ══════════════════════════════════════════════════════════════════════

    modifier onlyOwner() {
        require(msg.sender == registryOwner, "Not registry owner");
        _;
    }

    modifier onlyController() {
        require(controllers[msg.sender], "Not a controller");
        _;
    }

    modifier onlyNodeOwner(bytes32 node) {
        require(records[node].owner == msg.sender, "Not domain owner");
        _;
    }

    modifier notExpired(bytes32 node) {
        require(records[node].expiry > block.timestamp, "Domain expired");
        _;
    }

    // ══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════

    constructor(string memory _tld, bytes32 _tldNode) {
        tld = _tld;
        tldNode = _tldNode;
        registryOwner = msg.sender;
        controllers[msg.sender] = true;
    }

    // ══════════════════════════════════════════════════════════════════════
    // REGISTRATION FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @dev Register a new name
     * @param node Namehash of the domain
     * @param name Human-readable name (for events)
     * @param owner Owner address
     * @param duration Registration duration in seconds
     */
    function register(
        bytes32 node,
        string calldata name,
        address owner,
        uint256 duration
    ) external onlyController returns (uint256) {
        require(duration >= MIN_REGISTRATION_DURATION, "Duration too short");
        require(owner != address(0), "Invalid owner");

        uint256 expiry = block.timestamp + duration;

        // Check if available (not registered or expired with grace period)
        Record storage record = records[node];
        if (record.owner != address(0)) {
            require(
                record.expiry + GRACE_PERIOD < block.timestamp,
                "Name not available"
            );
        }

        // Register
        record.owner = owner;
        record.expiry = uint64(expiry);

        emit NameRegistered(node, name, owner, expiry);

        return expiry;
    }

    /**
     * @dev Renew a name registration
     * @param node Namehash of the domain
     * @param duration Additional duration in seconds
     */
    function renew(bytes32 node, uint256 duration)
        external
        onlyController
        returns (uint256)
    {
        require(duration >= MIN_REGISTRATION_DURATION, "Duration too short");

        Record storage record = records[node];
        require(record.owner != address(0), "Name not registered");

        // Extend from current expiry or now (whichever is later)
        uint256 baseTime = record.expiry > block.timestamp
            ? record.expiry
            : block.timestamp;

        uint256 newExpiry = baseTime + duration;
        record.expiry = uint64(newExpiry);

        emit NameRenewed(node, newExpiry);

        return newExpiry;
    }

    // ══════════════════════════════════════════════════════════════════════
    // OWNER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @dev Transfer domain ownership
     * @param node Namehash of the domain
     * @param newOwner New owner address
     */
    function transfer(bytes32 node, address newOwner)
        external
        onlyNodeOwner(node)
        notExpired(node)
    {
        require(newOwner != address(0), "Invalid new owner");

        records[node].owner = newOwner;

        emit Transfer(node, newOwner);
    }

    /**
     * @dev Set resolver for a domain
     * @param node Namehash of the domain
     * @param resolver Resolver contract address
     */
    function setResolver(bytes32 node, address resolver)
        external
        onlyNodeOwner(node)
        notExpired(node)
    {
        records[node].resolver = resolver;

        emit NewResolver(node, resolver);
    }

    // ══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @dev Get domain owner
     * @param node Namehash of the domain
     */
    function owner(bytes32 node) external view returns (address) {
        if (records[node].expiry < block.timestamp) {
            return address(0);
        }
        return records[node].owner;
    }

    /**
     * @dev Get resolver for a domain
     * @param node Namehash of the domain
     */
    function resolver(bytes32 node) external view returns (address) {
        if (records[node].expiry < block.timestamp) {
            return address(0);
        }
        return records[node].resolver;
    }

    /**
     * @dev Check if name is available for registration
     * @param node Namehash of the domain
     */
    function available(bytes32 node) external view returns (bool) {
        Record storage record = records[node];

        if (record.owner == address(0)) {
            return true;
        }

        // Available if expired + grace period passed
        return record.expiry + GRACE_PERIOD < block.timestamp;
    }

    /**
     * @dev Get expiry timestamp for a domain
     * @param node Namehash of the domain
     */
    function nameExpires(bytes32 node) external view returns (uint256) {
        return records[node].expiry;
    }

    // ══════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @dev Add a controller (can register names)
     * @param controller Controller address
     */
    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
        emit ControllerAdded(controller);
    }

    /**
     * @dev Remove a controller
     * @param controller Controller address
     */
    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
        emit ControllerRemoved(controller);
    }

    /**
     * @dev Transfer registry ownership
     * @param newOwner New registry owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        registryOwner = newOwner;
    }
}
