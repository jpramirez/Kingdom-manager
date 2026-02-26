"""Notification endpoints — list, mark-read, device-tokens, WebSocket."""

from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.database import get_db
from ...core.dependencies import get_current_user
from ...core.security import decode_access_token
from ...core.ws_manager import ws_manager
from ...models.household import HouseholdMember
from ...models.user import User
from ...schemas.notification import DeviceTokenRequest, NotificationReadRequest, NotificationResponse
from ...services import notification_service

router = APIRouter(tags=["Notifications"])
ws_router = APIRouter()  # Separate router for WebSocket (no API prefix)


# ── REST endpoints ──────────────────────────────────────────────


@router.get("/notifications", response_model=list[NotificationResponse])
async def list_notifications(
    unread_only: bool = Query(False),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await notification_service.list_notifications(
        db, current_user.id, unread_only=unread_only, limit=limit, offset=offset
    )


@router.get("/notifications/unread-count")
async def get_unread_count(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    count = await notification_service.unread_count(db, current_user.id)
    return {"count": count}


@router.post("/notifications/read")
async def mark_notifications_read(
    data: NotificationReadRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    updated = await notification_service.mark_read(
        db, current_user.id, data.notification_ids
    )
    return {"updated": updated}


@router.post("/notifications/read-all")
async def mark_all_notifications_read(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    updated = await notification_service.mark_all_read(db, current_user.id)
    return {"updated": updated}


@router.post("/notifications/device-token")
async def register_device_token(
    data: DeviceTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    dt = await notification_service.register_device_token(
        db, current_user.id, data.token, data.platform
    )
    return {"id": dt.id, "token": dt.token, "platform": dt.platform}


@router.delete("/notifications/device-token")
async def unregister_device_token(
    data: DeviceTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await notification_service.unregister_device_token(db, current_user.id, data.token)
    return {"message": "Device token removed"}


# ── WebSocket endpoint ──────────────────────────────────────────


@ws_router.websocket("/ws/notifications")
async def websocket_notifications(
    websocket: WebSocket,
    token: str = Query(...),
):
    """Authenticated WebSocket.  Client connects with ?token=<access_token>.
    Once connected, the server pushes real-time notification events."""

    # Authenticate via access token
    user_id = decode_access_token(token)
    if not user_id:
        await websocket.close(code=4001, reason="Invalid token")
        return

    # Resolve household memberships for broadcast routing
    async with websocket.app.state.db_session() as db:
        result = await db.execute(
            select(HouseholdMember.household_id).where(
                HouseholdMember.user_id == user_id
            )
        )
        household_ids = [row[0] for row in result.all()]

    await ws_manager.connect(websocket, user_id, household_ids)
    try:
        while True:
            # Keep the connection alive; clients can also send ping/ack
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket, user_id)
    except Exception:
        ws_manager.disconnect(websocket, user_id)
