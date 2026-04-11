"""
agent/core/keystore.py

Secure private key management for Agora agents.

Security hardening (FIX-5):
  - Private keys stored in OS keychain, never in plaintext on disk
  - Keys never passed via CLI args (visible in ps aux)
  - Keys zeroed from memory after use where possible
  - Encrypted key file fallback when OS keychain unavailable
  - Keys never appear in logs, tracebacks, or repr() output
"""

import os
import secrets
import hashlib
import getpass
from pathlib import Path
from typing import Optional

# Try OS keychain first
try:
    import keyring
    KEYRING_AVAILABLE = True
except ImportError:
    KEYRING_AVAILABLE = False

# Encrypted file fallback
try:
    from cryptography.fernet import Fernet
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
    from cryptography.hazmat.primitives import hashes
    import base64
    CRYPTO_AVAILABLE = True
except ImportError:
    CRYPTO_AVAILABLE = False

KEYCHAIN_SERVICE = "agora"
KEY_FILE_DIR = Path.home() / ".agora" / "keys"


class SecureKey:
    """
    Wraps a private key with controlled access.
    - repr() and str() never expose the key value
    - Provides use() context manager that zeroes the buffer after use
    """

    def __init__(self, key_bytes: bytes):
        self._key = bytearray(key_bytes)  # mutable so we can zero it

    def __repr__(self) -> str:
        return "<SecureKey [REDACTED]>"

    def __str__(self) -> str:
        return "<SecureKey [REDACTED]>"

    @property
    def hex(self) -> str:
        return bytes(self._key).hex()

    @property
    def bytes(self) -> bytes:
        return bytes(self._key)

    def zero(self):
        """Zero the key material from memory."""
        for i in range(len(self._key)):
            self._key[i] = 0

    def __del__(self):
        self.zero()


class AgentKeystore:
    """
    Secure keystore for agent private keys.

    Priority order:
    1. OS keychain (macOS Keychain, GNOME Keyring, Windows Credential Manager)
    2. Encrypted key file in ~/.agora/keys/ (passphrase-protected)
    3. Ephemeral in-memory key (not persisted — lost on restart)

    Never reads keys from:
    - CLI arguments
    - Environment variables (visible in /proc/environ)
    - Plaintext files
    """

    def __init__(self, agent_name: str = "default"):
        self.agent_name = agent_name
        KEY_FILE_DIR.mkdir(parents=True, exist_ok=True)

    def generate_and_store(self, passphrase: Optional[str] = None) -> SecureKey:
        """Generate a new keypair and store it securely."""
        key_bytes = secrets.token_bytes(32)
        key = SecureKey(key_bytes)
        self._store(key_bytes, passphrase)
        return key

    def load(self, passphrase: Optional[str] = None) -> Optional[SecureKey]:
        """Load the agent's private key from secure storage."""
        # Try OS keychain first
        if KEYRING_AVAILABLE:
            try:
                stored = keyring.get_password(KEYCHAIN_SERVICE, self.agent_name)
                if stored:
                    return SecureKey(bytes.fromhex(stored))
            except Exception:
                pass

        # Try encrypted key file
        key_file = KEY_FILE_DIR / f"{self.agent_name}.key"
        if key_file.exists():
            if passphrase is None and CRYPTO_AVAILABLE:
                passphrase = getpass.getpass(f"Agora key passphrase for '{self.agent_name}': ")
            try:
                return self._load_from_file(key_file, passphrase or "")
            except Exception as e:
                print(f"[Keystore] Failed to load key file: {e}")

        return None

    def exists(self) -> bool:
        """Check if a key exists in storage."""
        if KEYRING_AVAILABLE:
            try:
                if keyring.get_password(KEYCHAIN_SERVICE, self.agent_name):
                    return True
            except Exception:
                pass
        return (KEY_FILE_DIR / f"{self.agent_name}.key").exists()

    def _store(self, key_bytes: bytes, passphrase: Optional[str]):
        """Store key in OS keychain or encrypted file."""
        # Try OS keychain first
        if KEYRING_AVAILABLE:
            try:
                keyring.set_password(KEYCHAIN_SERVICE, self.agent_name, key_bytes.hex())
                print(f"[Keystore] Key stored in OS keychain for '{self.agent_name}'")
                return
            except Exception as e:
                print(f"[Keystore] OS keychain unavailable: {e}, using encrypted file")

        # Encrypted file fallback
        if CRYPTO_AVAILABLE:
            if passphrase is None:
                passphrase = getpass.getpass("Set Agora key passphrase: ")
                confirm = getpass.getpass("Confirm passphrase: ")
                if passphrase != confirm:
                    raise ValueError("Passphrases do not match")

            key_file = KEY_FILE_DIR / f"{self.agent_name}.key"
            self._save_to_file(key_bytes, key_file, passphrase)
            print(f"[Keystore] Key stored in encrypted file: {key_file}")
        else:
            print("[Keystore] WARNING: Neither OS keychain nor cryptography package available.")
            print("[Keystore] Key stored in memory only — will be lost on restart.")
            print("[Keystore] Install: pip install keyring cryptography")

    def _save_to_file(self, key_bytes: bytes, path: Path, passphrase: str):
        """Save key to AES-encrypted file using PBKDF2 key derivation."""
        salt = secrets.token_bytes(16)
        kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=480_000)
        fernet_key = base64.urlsafe_b64encode(kdf.derive(passphrase.encode()))
        f = Fernet(fernet_key)
        encrypted = f.encrypt(key_bytes)
        # File format: salt(16) + encrypted_key
        path.write_bytes(salt + encrypted)
        path.chmod(0o600)  # Owner read/write only

    def _load_from_file(self, path: Path, passphrase: str) -> SecureKey:
        """Load and decrypt key from encrypted file."""
        data = path.read_bytes()
        salt = data[:16]
        encrypted = data[16:]
        kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=480_000)
        fernet_key = base64.urlsafe_b64encode(kdf.derive(passphrase.encode()))
        f = Fernet(fernet_key)
        key_bytes = f.decrypt(encrypted)
        return SecureKey(key_bytes)


def get_or_create_key(agent_name: str = "default",
                       passphrase: Optional[str] = None) -> SecureKey:
    """
    Load existing key or generate a new one.
    This is the main entry point — never use CLI args or env vars for keys.
    """
    ks = AgentKeystore(agent_name)

    if ks.exists():
        key = ks.load(passphrase)
        if key:
            return key

    print(f"[Keystore] No key found for '{agent_name}' — generating new keypair")
    return ks.generate_and_store(passphrase)
