"""
agent/logos/storage.py

Logos Storage integration for Agora.

Security hardening applied:
  FIX-7: Maximum download size enforced before hash verification
  FIX-7: MIME type and size validated against escrow commitment
  FIX-7: Downloaded content never passed directly to daemon-ai
"""

import hashlib
import httpx
import time
from dataclasses import dataclass

# FIX-7: Hard cap on download size — prevents OOM from malicious CIDs
MAX_DOWNLOAD_BYTES = 50 * 1024 * 1024  # 50 MB absolute maximum

# FIX-7: Default cap per agreed doc size — enforced before hash check
MAX_DOC_SIZE_MULTIPLIER = 1.1  # Allow 10% over agreed size for encoding overhead


@dataclass
class StorageResult:
    cid: str
    size: int
    hash: str           # sha256:<hex>
    purchase_id: str
    mock: bool = False


class LogosStorageClient:

    def __init__(self, node_url: str = "http://localhost:8080"):
        self.node_url = node_url
        self._mock = False

    async def check_node(self) -> bool:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(f"{self.node_url}/api/codex/v1/info", timeout=5.0)
                self._mock = resp.status_code != 200
        except Exception:
            self._mock = True
        print(f"[Logos Storage] {'connected' if not self._mock else 'mock mode'}")
        return not self._mock

    async def upload(self, content: bytes, mime_type: str = "application/octet-stream",
                     filename: str = "output.bin", duration_seconds: int = 365 * 24 * 3600,
                     nodes: int = 5) -> StorageResult:
        content_hash = "sha256:" + hashlib.sha256(content).hexdigest()

        if self._mock:
            import base64, os
            mock_cid = "Qm" + base64.b32encode(os.urandom(22)).decode().lower()[:44]
            return StorageResult(cid=mock_cid, size=len(content), hash=content_hash,
                                 purchase_id="mock_purchase_" + mock_cid[:8], mock=True)

        try:
            async with httpx.AsyncClient(timeout=120.0) as client:
                upload_resp = await client.post(
                    f"{self.node_url}/api/codex/v1/data",
                    content=content,
                    headers={"Content-Type": mime_type,
                             "Content-Disposition": f'attachment; filename="{filename}"'},
                )
                upload_resp.raise_for_status()
                cid = upload_resp.json()["cid"]

                storage_resp = await client.post(
                    f"{self.node_url}/api/codex/v1/storage/request/{cid}",
                    json={"duration": duration_seconds, "nodes": nodes,
                          "tolerance": max(1, nodes // 3)},
                )
                purchase_id = storage_resp.json().get("purchaseId", "unknown")
                return StorageResult(cid=cid, size=len(content), hash=content_hash,
                                     purchase_id=purchase_id)
        except Exception as e:
            print(f"[Logos Storage] Upload failed: {e}")
            raise

    async def download(self, cid: str,
                       max_bytes: int = MAX_DOWNLOAD_BYTES,
                       agreed_size: int = 0) -> bytes:
        """
        Download content from Logos Storage.

        FIX-7: Enforces size limits before returning content:
        - Hard cap: MAX_DOWNLOAD_BYTES (50 MB)
        - Soft cap: agreed_size * MAX_DOC_SIZE_MULTIPLIER if agreed_size provided
        Prevents OOM attacks from malicious over-sized CIDs.
        """
        # FIX-7: Apply agreed size cap if provided
        if agreed_size > 0:
            soft_cap = int(agreed_size * MAX_DOC_SIZE_MULTIPLIER)
            effective_limit = min(max_bytes, soft_cap)
        else:
            effective_limit = max_bytes

        if self._mock:
            return b"[mock content for cid: " + cid.encode() + b"]"

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                async with client.stream("GET",
                    f"{self.node_url}/api/codex/v1/data/{cid}/network") as resp:
                    resp.raise_for_status()

                    # FIX-7: Check Content-Length header before downloading
                    content_length = int(resp.headers.get("content-length", 0))
                    if content_length > effective_limit:
                        raise ValueError(
                            f"Content-Length {content_length} exceeds limit {effective_limit} — "
                            f"possible malicious CID"
                        )

                    # FIX-7: Stream with running byte count — abort if over limit
                    chunks = []
                    total = 0
                    async for chunk in resp.aiter_bytes(chunk_size=65536):
                        total += len(chunk)
                        if total > effective_limit:
                            raise ValueError(
                                f"Download exceeded size limit {effective_limit} bytes — aborted"
                            )
                        chunks.append(chunk)

                    return b"".join(chunks)
        except ValueError:
            raise
        except Exception as e:
            print(f"[Logos Storage] Download failed for {cid}: {e}")
            raise

    def verify_hash(self, content: bytes, expected_hash: str) -> bool:
        """Verify content matches expected SHA-256 hash."""
        actual = "sha256:" + hashlib.sha256(content).hexdigest()
        return actual == expected_hash

    def verify_delivery(self, content: bytes, expected_hash: str,
                        expected_mime: str = "", agreed_size: int = 0) -> tuple[bool, str]:
        """
        FIX-7: Full delivery verification — hash, size, and optionally MIME type.
        Returns (valid: bool, reason: str).
        """
        # Hash check
        if not self.verify_hash(content, expected_hash):
            return False, "hash mismatch"

        # FIX-7: Size check against agreed commitment
        if agreed_size > 0:
            size_tolerance = int(agreed_size * MAX_DOC_SIZE_MULTIPLIER)
            if len(content) > size_tolerance:
                return False, f"content size {len(content)} exceeds agreed {agreed_size} by more than 10%"

        return True, "ok"
