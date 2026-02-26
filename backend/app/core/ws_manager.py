"""WebSocket connection manager — keeps track of connected users and
provides methods to broadcast messages to individuals or household groups."""

import json
import logging
from collections import defaultdict

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ConnectionManager:
    """Manages WebSocket connections per user_id.

    A single user can have multiple connections (e.g. phone + tablet).
    We also maintain a reverse lookup of user→households so we can
    broadcast to all members of a household efficiently.
    """

    def __init__(self) -> None:
        # user_id  →  set of WebSocket connections
        self._connections: dict[str, set[WebSocket]] = defaultdict(set)
        # user_id  →  set of household_ids they belong to
        self._user_households: dict[str, set[str]] = defaultdict(set)
        # household_id  →  set of user_ids currently connected
        self._household_users: dict[str, set[str]] = defaultdict(set)

    async def connect(
        self, websocket: WebSocket, user_id: str, household_ids: list[str]
    ) -> None:
        await websocket.accept()
        self._connections[user_id].add(websocket)
        self._user_households[user_id] = set(household_ids)
        for hid in household_ids:
            self._household_users[hid].add(user_id)
        logger.info("WS connected: user=%s, households=%s", user_id, household_ids)

    def disconnect(self, websocket: WebSocket, user_id: str) -> None:
        self._connections[user_id].discard(websocket)
        if not self._connections[user_id]:
            # last connection for this user — clean up household maps
            del self._connections[user_id]
            for hid in self._user_households.pop(user_id, set()):
                self._household_users[hid].discard(user_id)
                if not self._household_users[hid]:
                    del self._household_users[hid]
        logger.info("WS disconnected: user=%s", user_id)

    async def send_to_user(self, user_id: str, data: dict) -> None:
        """Send a JSON message to all connections of a specific user."""
        payload = json.dumps(data, default=str)
        dead: list[WebSocket] = []
        for ws in self._connections.get(user_id, set()):
            try:
                await ws.send_text(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self._connections[user_id].discard(ws)

    async def broadcast_to_household(
        self, household_id: str, data: dict, *, exclude_user: str | None = None
    ) -> None:
        """Send a JSON message to every connected member of a household."""
        for uid in list(self._household_users.get(household_id, set())):
            if exclude_user and uid == exclude_user:
                continue
            await self.send_to_user(uid, data)

    @property
    def connected_count(self) -> int:
        return sum(len(socks) for socks in self._connections.values())


# Singleton instance used across the app
ws_manager = ConnectionManager()
