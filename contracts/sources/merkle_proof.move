// SPDX-License-Identifier: MIT
// Based on: OpenZeppelin Contracts (last updated v4.7.0) (utils/cryptography/MerkleProof.sol)

/// @title: merkle_proof
/// @dev These functions deal with verification of Merkle Tree proofs.
/// The proofs can be generated using the JavaScript library
/// https://github.com/miguelmota/merkletreejs[merkletreejs].
/// Note: the hashing algorithm should be sha256 and pair sorting should be enabled.
/// Example code below:
/// const { MerkleTree } = require('merkletreejs')
/// const SHA256 = require('crypto-js/sha256')
/// const leaves = ['a', 'b', 'c'].map(x => SHA256(x))
/// const tree = new MerkleTree(leaves, SHA256, { sortPairs: true })
/// const root = tree.getRoot().toString('hex')
/// const leaf = SHA256('a')
/// const proof = tree.getProof(leaf)
/// console.log(tree.verify(proof, leaf, root)) // true
/// TODO: Unit tests for multi-proof verification.
module contracts::merkle_proof {
    // use std::hash;
    use std::vector;
    use sui::hash;

    use contracts::vectors;
    use std::debug;

    /// @dev When an invalid multi-proof is supplied. Proof flags length must equal proof length + leaves length - 1.
    const EINVALID_MULTI_PROOF: u64 = 0x10000;

    /// @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
    /// defined by `root`. For this, a `proof` must be provided, containing
    /// sibling hashes on the branch from the leaf to the root of the tree. Each
    /// pair of leaves and each pair of pre-images are assumed to be sorted.
    public fun verify(
        proof: &vector<vector<u8>>,
        root: vector<u8>,
        leaf: vector<u8>
    ): bool {
        debug::print(&process_proof(proof, leaf));
        process_proof(proof, leaf) == root
    }

    /// @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
    /// from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
    /// hash matches the root of the tree. When processing the proof, the pairs
    /// of leafs & pre-images are assumed to be sorted.
    fun process_proof(proof: &vector<vector<u8>>, leaf: vector<u8>): vector<u8> {
        let computed_hash = leaf;
        let proof_length = vector::length(proof);
        let i = 0;

        while (i < proof_length) {
            computed_hash = hash_pair(computed_hash, *vector::borrow(proof, i));
            i = i + 1;
        };

        computed_hash
    }

    /// @dev Returns true if the `leaves` can be proved to be a part of a Merkle tree defined by
    /// `root`, according to `proof` and `proofFlags` as described in {processMultiProof}.
    public fun multi_proof_verify(
        proof: &vector<vector<u8>>,
        proof_flags: &vector<bool>,
        root: vector<u8>,
        leaves: &vector<vector<u8>>
    ): bool {
        process_multi_proof(proof, proof_flags, leaves) == root
    }

    /// @dev Returns the root of a tree reconstructed from `leaves` and the sibling nodes in `proof`,
    /// consuming from one or the other at each step according to the instructions given by
    /// `proofFlags`.
    fun process_multi_proof(
        proof: &vector<vector<u8>>,
        proof_flags: &vector<bool>,
        leaves: &vector<vector<u8>>,
    ): vector<u8> {
        // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        let leaves_len = vector::length(leaves);
        let total_hashes = vector::length(proof_flags);

        // Check proof validity.
        assert!(leaves_len + vector::length(proof) - 1 == total_hashes, EINVALID_MULTI_PROOF);

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        let hashes = vector::empty<vector<u8>>();
        let leaf_pos = 0;
        let hash_pos = 0;
        let proof_pos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
        //   `proof` array.
        let i = 0;

        while (i < total_hashes) {
            let a = if (leaf_pos < leaves_len) {
                leaf_pos = leaf_pos + 1;
                *vector::borrow(leaves, leaf_pos)
            } else {
                hash_pos = hash_pos + 1;
                *vector::borrow(&hashes, hash_pos)
            };

            let b = if (*vector::borrow(proof_flags, i)) {
                if (leaf_pos < leaves_len) {
                    leaf_pos = leaf_pos + 1;
                    *vector::borrow(leaves, leaf_pos)
                } else {
                    hash_pos = hash_pos + 1;
                    *vector::borrow(&hashes, hash_pos)
                }
            } else {
                proof_pos = proof_pos + 1;
                *vector::borrow(proof, proof_pos)
            };

            vector::push_back(&mut hashes, hash_pair(a, b));
            i = i + 1;
        };

        if (total_hashes > 0) {
            *vector::borrow(&hashes, total_hashes - 1)
        } else if (leaves_len > 0) {
            *vector::borrow(leaves, 0)
        } else {
            *vector::borrow(proof, 0)
        }
    }

    fun hash_pair(a: vector<u8>, b: vector<u8>): vector<u8> {
        if (vectors::lt(&a, &b)) efficient_hash(a, b) else efficient_hash(b, a)
    }

    fun efficient_hash(a: vector<u8>, b: vector<u8>): vector<u8> {
        vector::append(&mut a, b);
        hash::keccak256(&a)
        //hash::sha3_256(a)
    }

    #[test]
    fun test_verify() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009d");
        vector::push_back(&mut proof, x"2e7d2c03a9507ae265ecf5b5356885a53393a2029d241394997265a1a25aefc6");
        let root = x"aea2dd4249dcecf97ca6a1556db7f21ebd6a40bbec0243ca61b717146a08c347";
        let leaf = x"ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb";
        assert!(verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify_bad_proof() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"3e23e8160039594a33894f6564e1b1349bbd7a0088d42c4acb73eeaed59c009d");
        vector::push_back(&mut proof, x"2e7d2c03a9507ae265ecf5b5356885a53393a2029d241394997265a1a25aefc6");
        let root = x"aea2dd4249dcecf97ca6a1556db7f21ebd6a40bbec0243ca61b717146a08c347";
        let leaf = x"ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb";
        assert!(!verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify_bad_root() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009d");
        vector::push_back(&mut proof, x"2e7d2c03a9507ae265ecf5b5356885a53393a2029d241394997265a1a25aefc6");
        let root = x"aea9dd4249dcecf97ca6a1556db7f21ebd6a40bbec0243ca61b717146a08c347";
        let leaf = x"ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb";
        assert!(!verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify_bad_leaf() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009d");
        vector::push_back(&mut proof, x"2e7d2c03a9507ae265ecf5b5356885a53393a2029d241394997265a1a25aefc6");
        let root = x"aea2dd4249dcecf97ca6a1556db7f21ebd6a40bbec0243ca61b717146a08c347";
        let leaf = x"ca978112ca1bbdc1fac231b39a23dc4da786eff8147c4e72b9807785afee48bb";
        assert!(!verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify2() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"92b20ca902413bb1363f503be9d74e14db20690e75e245cd4f13a8afdfd680a7");
        vector::push_back(&mut proof, x"04d7147ff8034684b08881246cb01f800262780989ae3b0a5f97908a2597bf76");
        let root = x"aa74198cd9e85849f52d9c3fb319b2bdcb4ab1207911b5eadcf36f8f973abf01";
        let leaf = x"b2d2afd80ddd428bd589ea602fa0375264c356b34705cf878296c1608e306a46";
        assert!(verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify3() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"c3698dd03a88b165f793c9fe53fdd1d7b2a49d722f26a4cb8fb469af18c7a3aa");
        vector::push_back(&mut proof, x"a6cc3c67adf524caa8e8db3c5743acf327400925b987a2b06523ce66b13a05f1");
        let root = x"3d72421d509a3b8e3bb57bd10ec8a52ca0a991cde31aae53e885d0db67f082d7";
        let leaf = x"1ed2be2c6a337feed7066671cacf921b49baadd222adedd388c4ce95fd17b65c";
        assert!(verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify4() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"b2d2afd80ddd428bd589ea602fa0375264c356b34705cf878296c1608e306a46");
        vector::push_back(&mut proof, x"5c6da5dbe0ceb5226ea5ad9d75cd3c1f77f4c46de4ddb364300c0cc125d3eb2c");
        let root = x"cdc69093c5e11d624430354597205ec0239c3b7fa5c94a8f800fcabc06cf566a";
        let leaf = x"92b20ca902413bb1363f503be9d74e14db20690e75e245cd4f13a8afdfd680a7";
        assert!(verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify5() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"5c6da5dbe0ceb5226ea5ad9d75cd3c1f77f4c46de4ddb364300c0cc125d3eb2c");
        vector::push_back(&mut proof, x"e1aa2639d3f0f00425ff8a0d29d5e48006281a618a2f714c88940f010ccfb5c7");
        let root = x"9f89702a70349140f67d9b0e7a5f8bace9e53766e222ec4868adb3dc4569d61f";
        let leaf = x"9ddb9cb6ab0cb5dd038e2aef2f301098ee574830089d3a3f812ad8c59dcbc6e6";
        assert!(verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify6() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"92b20ca902413bb1363f503be9d74e14db20690e75e245cd4f13a8afdfd680a7");
        vector::push_back(&mut proof, x"04d7147ff8034684b08881246cb01f800262780989ae3b0a5f97908a2597bf76");
        let root = x"aa74198cd9e85849f52d9c3fb319b2bdcb4ab1207911b5eadcf36f8f973abf01";
        let leaf = x"b2d2afd80ddd428bd589ea602fa0375264c356b34705cf878296c1608e306a46";
        assert!(verify(&proof, root, leaf), 0);
    }

    #[test]
    fun test_verify7() {
        let proof = vector::empty<vector<u8>>();
        vector::push_back(&mut proof, x"e5a01fee14e0ed5c48714f22180f25ad8365b53f9779f79dc4a3d7e93963f94a");
        //vector::push_back(&mut proof, x"2e7d2c03a9507ae265ecf5b5356885a53393a2029d241394997265a1a25aefc6");
        let root = x"7075152d03a5cd92104887b476862778ec0c87be5c2fa1c0a90f87c49fad6eff";
        let leaf = x"2e7d2c03a9507ae265ecf5b5356885a53393a2029d241394997265a1a25aefc6";
        assert!(verify(&proof, root, leaf), 0);
    }
}