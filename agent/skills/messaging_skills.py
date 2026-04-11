"""
agent/skills/messaging_skills.py

LP-0008 required messaging skills using Logos Messaging (Waku).

Skills:
  messaging.send         — send message to a Logos Messaging address
  messaging.join         — join a Logos Messaging group topic
  messaging.create_group — create new group topic with invitations
"""

from agent.skills.base import Skill, SkillContext, SkillResult
from agent.logos.messaging import LogosMessagingClient


class MessagingSendSkill(Skill):
    name = "messaging.send"
    description = "Send a message to a Logos Messaging address"
    category = "messaging"
    parameters = {
        "recipient": {"type": "string", "required": True, "description": "Recipient's Logos Messaging address"},
        "message": {"type": "string", "required": True, "description": "Message content"},
    }

    def __init__(self, messaging: LogosMessagingClient):
        self._messaging = messaging

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        result = await self._messaging.send(params["recipient"], params["message"])
        return SkillResult.ok({
            "sent": True,
            "recipient": params["recipient"],
            "message_id": result.get("message_id", ""),
        })


class MessagingJoinSkill(Skill):
    name = "messaging.join"
    description = "Join a Logos Messaging group topic"
    category = "messaging"
    parameters = {
        "group_id": {"type": "string", "required": True, "description": "Group topic ID to join"},
    }

    def __init__(self, messaging: LogosMessagingClient):
        self._messaging = messaging

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        result = await self._messaging.join_group(params["group_id"])
        return SkillResult.ok({
            "joined": True,
            "group_id": params["group_id"],
            "members": result.get("members", []),
        })


class MessagingCreateGroupSkill(Skill):
    name = "messaging.create_group"
    description = "Create a new group topic and invite members"
    category = "messaging"
    parameters = {
        "members": {"type": "string", "required": True, "description": "Comma-separated list of member Logos addresses"},
    }

    def __init__(self, messaging: LogosMessagingClient):
        self._messaging = messaging

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        member_list = [m.strip() for m in params["members"].split(",") if m.strip()]
        result = await self._messaging.create_group(member_list)
        return SkillResult.ok({
            "group_id": result.get("group_id", ""),
            "members": member_list,
            "created": True,
        })


def register_messaging_skills(registry, messaging: LogosMessagingClient):
    """Register all messaging skills with the given registry."""
    registry.register(MessagingSendSkill(messaging))
    registry.register(MessagingJoinSkill(messaging))
    registry.register(MessagingCreateGroupSkill(messaging))
