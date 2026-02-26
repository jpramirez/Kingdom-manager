from datetime import datetime

from pydantic import BaseModel, Field


class CommentCreateRequest(BaseModel):
    text: str | None = Field(None, max_length=2000)
    entity_type: str = Field(pattern=r"^(chore|event|grocery_list|grocery_item|assignment)$")
    entity_id: str


class CommentResponse(BaseModel):
    id: str
    household_id: str
    entity_type: str
    entity_id: str
    user_id: str
    text: str | None = None
    display_name: str  # from user join
    avatar_url: str | None = None
    attachments: list["AttachmentResponse"] = []
    created_at: datetime

    model_config = {"from_attributes": True}


class AttachmentCreateResponse(BaseModel):
    id: str
    file_url: str
    file_name: str
    file_type: str
    file_size: int
    thumbnail_url: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class AttachmentResponse(BaseModel):
    id: str
    entity_type: str
    entity_id: str
    user_id: str
    file_url: str
    file_name: str
    file_type: str
    file_size: int
    thumbnail_url: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}
