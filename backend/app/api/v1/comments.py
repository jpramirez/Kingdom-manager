from fastapi import APIRouter, Depends, File, Query, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.database import get_db
from ...core.dependencies import get_current_user
from ...models.user import User
from ...schemas.auth import MessageResponse
from ...schemas.comment import AttachmentResponse, CommentCreateRequest, CommentResponse
from ...services import comment_service

router = APIRouter(prefix="/households", tags=["Comments & Attachments"])


# --- Comments ---


@router.post("/{household_id}/comments/", response_model=CommentResponse, status_code=201)
async def create_comment(
    household_id: str,
    data: CommentCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await comment_service.create_comment(db, household_id, data, current_user)


@router.get("/{household_id}/comments/", response_model=list[CommentResponse])
async def list_comments(
    household_id: str,
    entity_type: str = Query(..., pattern=r"^(chore|event|grocery_list|grocery_item|assignment)$"),
    entity_id: str = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await comment_service.list_comments(db, household_id, entity_type, entity_id, current_user)


@router.delete("/{household_id}/comments/{comment_id}", response_model=MessageResponse)
async def delete_comment(
    household_id: str,
    comment_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await comment_service.delete_comment(db, household_id, comment_id, current_user)
    return MessageResponse(message="Comment deleted")


# --- Attachments (image upload) ---


@router.post("/{household_id}/attachments/", response_model=AttachmentResponse, status_code=201)
async def upload_attachment(
    household_id: str,
    entity_type: str = Query(..., pattern=r"^(chore|event|comment|assignment|grocery_item)$"),
    entity_id: str = Query(...),
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await comment_service.upload_attachment(
        db, household_id, entity_type, entity_id, current_user, file
    )


@router.get("/{household_id}/attachments/", response_model=list[AttachmentResponse])
async def list_attachments(
    household_id: str,
    entity_type: str = Query(...),
    entity_id: str = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await comment_service.list_attachments(db, household_id, entity_type, entity_id, current_user)
