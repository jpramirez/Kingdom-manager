from datetime import datetime

from pydantic import BaseModel


class NotificationResponse(BaseModel):
    id: str
    user_id: str
    household_id: str | None = None
    title: str
    body: str
    notification_type: str
    reference_id: str | None = None
    reference_type: str | None = None
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class NotificationReadRequest(BaseModel):
    notification_ids: list[str]


class DeviceTokenRequest(BaseModel):
    token: str
    platform: str  # ios or android
