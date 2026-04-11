/// contracts/common/src/lib.rs
///
/// Shared types, errors and helpers for all Agora LSSA contracts.
/// Compiled as a dependency by identity, escrow, and reputation contracts.

use std::collections::BTreeMap;

// ── Core types ────────────────────────────────────────────────────

/// Compressed secp256k1 public key, 33 bytes, hex-encoded.
pub type AgentId = String;

/// NOM token amount as u128 base units (1 NOM = 1_000_000 base units).
pub type NomAmount = u128;

/// SHA-256 hash, hex-encoded with "sha256:" prefix.
pub type HashDigest = String;

/// Logos Blockchain LSSA block number.
pub type BlockNumber = u64;

/// Unix timestamp in milliseconds.
pub type TimestampMs = u64;

// ── Errors ────────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq)]
pub enum ContractError {
    // Identity errors
    AlreadyRegistered,
    NotRegistered,
    InsufficientStake,

    // Escrow errors
    EscrowNotFound,
    EscrowAlreadyExists,
    EscrowNotPending,
    EscrowExpired,
    EscrowNotExpired,
    HashMismatch,
    UnauthorisedCaller,
    InsufficientFunds,

    // Reputation errors
    NoTradeHistory,
    InvalidScore,

    // General
    InvalidInput(String),
    Overflow,
}

impl std::fmt::Display for ContractError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ContractError::AlreadyRegistered     => write!(f, "agent already registered"),
            ContractError::NotRegistered         => write!(f, "agent not registered"),
            ContractError::InsufficientStake     => write!(f, "insufficient stake"),
            ContractError::EscrowNotFound        => write!(f, "escrow not found"),
            ContractError::EscrowAlreadyExists   => write!(f, "escrow already exists"),
            ContractError::EscrowNotPending      => write!(f, "escrow is not in pending state"),
            ContractError::EscrowExpired         => write!(f, "escrow has expired"),
            ContractError::EscrowNotExpired      => write!(f, "escrow has not expired yet"),
            ContractError::HashMismatch          => write!(f, "delivery hash does not match commitment"),
            ContractError::UnauthorisedCaller    => write!(f, "caller is not authorised"),
            ContractError::InsufficientFunds     => write!(f, "insufficient NOM balance"),
            ContractError::NoTradeHistory        => write!(f, "no trade history for agent"),
            ContractError::InvalidScore          => write!(f, "score must be between 0 and 10000"),
            ContractError::InvalidInput(msg)     => write!(f, "invalid input: {}", msg),
            ContractError::Overflow              => write!(f, "arithmetic overflow"),
        }
    }
}

pub type Result<T> = std::result::Result<T, ContractError>;

// ── NOM ledger (simplified — LSSA handles real token logic) ───────

/// Simple NOM balance ledger for contract-internal accounting.
#[derive(Debug, Default, Clone)]
pub struct NomLedger {
    balances: BTreeMap<AgentId, NomAmount>,
}

impl NomLedger {
    pub fn credit(&mut self, agent: &AgentId, amount: NomAmount) {
        let balance = self.balances.entry(agent.clone()).or_insert(0);
        *balance = balance.saturating_add(amount);
    }

    pub fn debit(&mut self, agent: &AgentId, amount: NomAmount) -> Result<()> {
        let balance = self.balances.get_mut(agent).ok_or(ContractError::InsufficientFunds)?;
        if *balance < amount {
            return Err(ContractError::InsufficientFunds);
        }
        *balance -= amount;
        Ok(())
    }

    pub fn balance(&self, agent: &AgentId) -> NomAmount {
        *self.balances.get(agent).unwrap_or(&0)
    }

    pub fn transfer(&mut self, from: &AgentId, to: &AgentId, amount: NomAmount) -> Result<()> {
        self.debit(from, amount)?;
        self.credit(to, amount);
        Ok(())
    }
}

// ── Events ────────────────────────────────────────────────────────

/// Emitted events — in production these are written to LSSA event log.
#[derive(Debug, Clone)]
pub enum Event {
    AgentRegistered {
        agent_id:     AgentId,
        stake:        NomAmount,
        block:        BlockNumber,
    },
    AgentDeregistered {
        agent_id:     AgentId,
        stake_return: NomAmount,
        block:        BlockNumber,
    },
    EscrowCreated {
        escrow_id:    String,
        buyer_id:     AgentId,
        seller_id:    AgentId,
        amount:       NomAmount,
        timeout_ms:   TimestampMs,
        block:        BlockNumber,
    },
    EscrowReleased {
        escrow_id:    String,
        seller_id:    AgentId,
        amount:       NomAmount,
        block:        BlockNumber,
    },
    EscrowSlashed {
        escrow_id:    String,
        slash_amount: NomAmount,
        reason:       String,
        block:        BlockNumber,
    },
    EscrowRefunded {
        escrow_id:    String,
        buyer_id:     AgentId,
        amount:       NomAmount,
        block:        BlockNumber,
    },
    ReputationUpdated {
        agent_id:     AgentId,
        old_score:    u32,
        new_score:    u32,
        trade_count:  u64,
        block:        BlockNumber,
    },
    StakeSlashed {
        agent_id:     AgentId,
        slash_amount: NomAmount,
        reason:       String,
        block:        BlockNumber,
    },
}

/// Minimum stake to register an agent identity (1000 NOM).
pub const MIN_STAKE_NOM: NomAmount = 1_000_000_000; // 1000 NOM in base units

/// Reputation score scale: 0–10000 (representing 0.00–100.00%).
pub const MAX_REPUTATION: u32 = 10_000;

/// Initial reputation score for new agents (50%).
pub const INITIAL_REPUTATION: u32 = 5_000;

/// Minimum reputation to participate in high-value trades (70%).
pub const MIN_REPUTATION_HIGH_VALUE: u32 = 7_000;

/// High-value trade threshold (100 NOM).
pub const HIGH_VALUE_THRESHOLD_NOM: NomAmount = 100_000_000; // 100 NOM in base units
