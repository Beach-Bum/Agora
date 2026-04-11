"""
agent/skills/storage_skills.py

LP-0008 required storage skills using Logos Storage (Codex).

Skills:
  storage.upload   — encrypt and upload file, return content address
  storage.download — retrieve and decrypt file locally
  storage.list     — list stored files with labels and addresses
  storage.share    — share file access with a Logos identity
"""

from agent.skills.base import Skill, SkillContext, SkillResult
from agent.logos.storage import LogosStorageClient


class StorageUploadSkill(Skill):
    name = "storage.upload"
    description = "Encrypt and upload a file to Logos Storage; returns content address"
    category = "storage"
    parameters = {
        "path": {"type": "string", "required": True, "description": "Local file path to upload"},
        "label": {"type": "string", "required": True, "description": "Human-readable label for the file"},
    }

    def __init__(self, storage: LogosStorageClient):
        self._storage = storage

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        result = await self._storage.upload(params["path"], params["label"])
        return SkillResult.ok({
            "content_address": result["cid"],
            "label": params["label"],
            "size_bytes": result.get("size", 0),
        })


class StorageDownloadSkill(Skill):
    name = "storage.download"
    description = "Retrieve and decrypt a file from Logos Storage to local path"
    category = "storage"
    parameters = {
        "address": {"type": "string", "required": True, "description": "Content address (CID)"},
        "path": {"type": "string", "required": True, "description": "Local path to save file"},
    }

    def __init__(self, storage: LogosStorageClient):
        self._storage = storage

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        result = await self._storage.download(params["address"], params["path"])
        return SkillResult.ok({
            "path": params["path"],
            "content_address": params["address"],
            "verified": result.get("verified", False),
        })


class StorageListSkill(Skill):
    name = "storage.list"
    description = "List stored files with labels and content addresses"
    category = "storage"
    parameters = {}

    def __init__(self, storage: LogosStorageClient):
        self._storage = storage

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        files = await self._storage.list_files()
        return SkillResult.ok({"files": files, "count": len(files)})


class StorageShareSkill(Skill):
    name = "storage.share"
    description = "Share file access with a Logos identity"
    category = "storage"
    parameters = {
        "address": {"type": "string", "required": True, "description": "Content address (CID)"},
        "recipient": {"type": "string", "required": True, "description": "Recipient's Logos identity (pub key)"},
    }

    def __init__(self, storage: LogosStorageClient):
        self._storage = storage

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        result = await self._storage.share(params["address"], params["recipient"])
        return SkillResult.ok({
            "shared": True,
            "content_address": params["address"],
            "recipient": params["recipient"],
        })


def register_storage_skills(registry, storage: LogosStorageClient):
    """Register all storage skills with the given registry."""
    registry.register(StorageUploadSkill(storage))
    registry.register(StorageDownloadSkill(storage))
    registry.register(StorageListSkill(storage))
    registry.register(StorageShareSkill(storage))
