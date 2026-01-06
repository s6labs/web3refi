// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniversalRegistry {
    function owner(bytes32 node) external view returns (address);
}

/**
 * @title UniversalResolver
 * @dev Universal name resolver for any blockchain
 *
 * This contract resolves names to addresses and stores metadata.
 * Compatible with ENS resolver interface for easy integration.
 *
 * Features:
 * - Address resolution (forward)
 * - Name resolution (reverse)
 * - Multi-coin address support
 * - Text records (email, url, avatar, etc.)
 * - Content hash (IPFS, etc.)
 * - ABI records
 */
contract UniversalResolver {

    // ══════════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ══════════════════════════════════════════════════════════════════════

    /// Registry contract
    IUniversalRegistry public registry;

    /// Forward resolution: namehash → coinType → address
    mapping(bytes32 => mapping(uint256 => bytes)) public addresses;

    /// Reverse resolution: address → name
    mapping(address => string) public names;

    /// Text records: namehash → key → value
    mapping(bytes32 => mapping(string => string)) public texts;

    /// Content hashes: namehash → contenthash
    mapping(bytes32 => bytes) private _contenthashes;

    /// ABI records: namehash → contentType → data
    mapping(bytes32 => mapping(uint256 => bytes)) public abis;

    // ══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════

    event AddressChanged(bytes32 indexed node, uint256 coinType, bytes newAddress);
    event NameChanged(bytes32 indexed node, string name);
    event TextChanged(bytes32 indexed node, string indexed key, string value);
    event ContenthashChanged(bytes32 indexed node, bytes hash);
    event ABIChanged(bytes32 indexed node, uint256 indexed contentType);

    // ══════════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ══════════════════════════════════════════════════════════════════════

    modifier authorised(bytes32 node) {
        require(
            registry.owner(node) == msg.sender,
            "Not authorised"
        );
        _;
    }

    // ══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════

    constructor(IUniversalRegistry _registry) {
        registry = _registry;
    }

    // ══════════════════════════════════════════════════════════════════════
    // SETTERS (Owner only)
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @dev Set address for a coin type
     * @param node Namehash of the domain
     * @param coinType Coin type (60 = ETH, 0 = BTC, etc.)
     * @param a Address bytes
     */
    function setAddr(bytes32 node, uint256 coinType, bytes calldata a)
        external
        authorised(node)
    {
        addresses[node][coinType] = a;
        emit AddressChanged(node, coinType, a);
    }

    /**
     * @dev Set Ethereum address (shorthand for coin type 60)
     * @param node Namehash of the domain
     * @param a Ethereum address
     */
    function setAddr(bytes32 node, address a)
        external
        authorised(node)
    {
        bytes memory addrBytes = _addressToBytes(a);
        addresses[node][60] = addrBytes;
        emit AddressChanged(node, 60, addrBytes);
    }

    /**
     * @dev Set reverse resolution (address → name)
     * @param name Domain name
     */
    function setName(bytes32 node, string calldata name)
        external
        authorised(node)
    {
        names[msg.sender] = name;
        emit NameChanged(node, name);
    }

    /**
     * @dev Set text record
     * @param node Namehash of the domain
     * @param key Record key (e.g., "email", "url", "avatar")
     * @param value Record value
     */
    function setText(bytes32 node, string calldata key, string calldata value)
        external
        authorised(node)
    {
        texts[node][key] = value;
        emit TextChanged(node, key, value);
    }

    /**
     * @dev Set content hash (IPFS, Arweave, etc.)
     * @param node Namehash of the domain
     * @param hash Content hash bytes
     */
    function setContenthash(bytes32 node, bytes calldata hash)
        external
        authorised(node)
    {
        _contenthashes[node] = hash;
        emit ContenthashChanged(node, hash);
    }

    /**
     * @dev Set ABI record
     * @param node Namehash of the domain
     * @param contentType Content type identifier
     * @param data ABI data
     */
    function setABI(bytes32 node, uint256 contentType, bytes calldata data)
        external
        authorised(node)
    {
        abis[node][contentType] = data;
        emit ABIChanged(node, contentType);
    }

    /**
     * @dev Set multiple records at once (gas optimization)
     * @param node Namehash of the domain
     * @param coinType Coin type
     * @param a Address bytes
     * @param textKeys Text record keys
     * @param textValues Text record values
     */
    function setRecords(
        bytes32 node,
        uint256 coinType,
        bytes calldata a,
        string[] calldata textKeys,
        string[] calldata textValues
    ) external authorised(node) {
        require(textKeys.length == textValues.length, "Array length mismatch");

        // Set address
        if (a.length > 0) {
            addresses[node][coinType] = a;
            emit AddressChanged(node, coinType, a);
        }

        // Set text records
        for (uint256 i = 0; i < textKeys.length; i++) {
            texts[node][textKeys[i]] = textValues[i];
            emit TextChanged(node, textKeys[i], textValues[i]);
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // GETTERS (Public)
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @dev Get address for a coin type
     * @param node Namehash of the domain
     * @param coinType Coin type
     */
    function addr(bytes32 node, uint256 coinType)
        external
        view
        returns (bytes memory)
    {
        return addresses[node][coinType];
    }

    /**
     * @dev Get Ethereum address (shorthand for coin type 60)
     * @param node Namehash of the domain
     */
    function addr(bytes32 node) external view returns (address) {
        bytes memory addrBytes = addresses[node][60];
        if (addrBytes.length == 0) {
            return address(0);
        }
        return _bytesToAddress(addrBytes);
    }

    /**
     * @dev Get reverse resolution name
     * @param addr Address to look up
     */
    function name(address addr) external view returns (string memory) {
        return names[addr];
    }

    /**
     * @dev Get text record
     * @param node Namehash of the domain
     * @param key Record key
     */
    function text(bytes32 node, string calldata key)
        external
        view
        returns (string memory)
    {
        return texts[node][key];
    }

    /**
     * @dev Get content hash
     * @param node Namehash of the domain
     */
    function contenthash(bytes32 node) external view returns (bytes memory) {
        return _contenthashes[node];
    }

    /**
     * @dev Get ABI record
     * @param node Namehash of the domain
     * @param contentTypes Content type identifiers (bitfield)
     */
    function ABI(bytes32 node, uint256 contentTypes)
        external
        view
        returns (uint256, bytes memory)
    {
        // Find first matching content type
        for (uint256 i = 0; i < 256; i++) {
            uint256 contentType = 1 << i;
            if ((contentTypes & contentType) != 0 && abis[node][contentType].length > 0) {
                return (contentType, abis[node][contentType]);
            }
        }
        return (0, bytes(""));
    }

    /**
     * @dev Check if this contract supports an interface
     * @param interfaceID Interface identifier
     */
    function supportsInterface(bytes4 interfaceID)
        external
        pure
        returns (bool)
    {
        return
            interfaceID == 0x01ffc9a7 || // ERC165
            interfaceID == 0x3b3b57de || // addr(bytes32)
            interfaceID == 0xf1cb7e06 || // addr(bytes32,uint256)
            interfaceID == 0x691f3431 || // name(bytes32)
            interfaceID == 0x59d1d43c || // text(bytes32,string)
            interfaceID == 0xbc1c58d1; // contenthash(bytes32)
    }

    // ══════════════════════════════════════════════════════════════════════
    // INTERNAL HELPERS
    // ══════════════════════════════════════════════════════════════════════

    function _addressToBytes(address a) internal pure returns (bytes memory) {
        bytes memory b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
        return b;
    }

    function _bytesToAddress(bytes memory b) internal pure returns (address) {
        require(b.length >= 20, "Invalid address bytes");
        address a;
        assembly {
            a := mload(add(b, 20))
        }
        return a;
    }
}
