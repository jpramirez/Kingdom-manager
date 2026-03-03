"""Service for comments and attachments on any entity."""

import os
import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..models.comment import Attachment, Comment
from ..models.user import User
from .permissions import require_membership
from ..schemas.comment import AttachmentResponse, CommentCreateRequest, CommentResponse


async def create_comment(
    db: AsyncSession,
    household_id: str,
    data: CommentCreateRequest,
    user: User,
) -> CommentResponse:
    await require_membership(db, household_id, user.id)

    comment = Comment(
        household_id=household_id,
        entity_type=data.entity_type,
        entity_id=data.entity_id,
        user_id=user.id,
        text=data.text,
    )
    db.add(comment)
    await db.flush()

    return CommentResponse(
        id=comment.id,
        household_id=comment.household_id,
        entity_type=comment.entity_type,
        entity_id=comment.entity_id,
        user_id=comment.user_id,
        text=comment.text,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        attachments=[],
        created_at=comment.created_at,
    )


async def list_comments(
    db: AsyncSession,
    household_id: str,
    entity_type: str,
    entity_id: str,
    user: User,
) -> list[CommentResponse]:
    await require_membership(db, household_id, user.id)

    result = await db.execute(
        select(Comment, User)
        .join(User, Comment.user_id == User.id)
        .where(
            Comment.household_id == household_id,
            Comment.entity_type == entity_type,
            Comment.entity_id == entity_id,
        )
        .order_by(Comment.created_at.asc())
    )
    rows = result.all()

    comments = []
    for comment, u in rows:
        # Get attachments for this comment
        att_result = await db.execute(
            select(Attachment).where(
                Attachment.entity_type == "comment",
                Attachment.entity_id == comment.id,
            )
        )
        attachments = [
            AttachmentResponse(
                id=a.id,
                entity_type=a.entity_type,
                entity_id=a.entity_id,
                user_id=a.user_id,
                file_url=a.file_url,
                file_name=a.file_name,
                file_type=a.file_type,
                file_size=a.file_size,
                thumbnail_url=a.thumbnail_url,
                created_at=a.created_at,
            )
            for a in att_result.scalars().all()
        ]

        comments.append(
            CommentResponse(
                id=comment.id,
                household_id=comment.household_id,
                entity_type=comment.entity_type,
                entity_id=comment.entity_id,
                user_id=comment.user_id,
                text=comment.text,
                display_name=u.display_name,
                avatar_url=u.avatar_url,
                attachments=attachments,
                created_at=comment.created_at,
            )
        )
    return comments


async def delete_comment(
    db: AsyncSession,
    household_id: str,
    comment_id: str,
    user: User,
) -> None:
    await require_membership(db, household_id, user.id)

    result = await db.execute(
        select(Comment).where(
            Comment.id == comment_id,
            Comment.household_id == household_id,
        )
    )
    comment = result.scalar_one_or_none()
    if not comment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Comment not found")

    # Only the author or an adult/admin can delete
    if comment.user_id != user.id:
        member = await require_membership(db, household_id, user.id)
        if member.role != "family_adult" and not member.is_admin:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot delete others' comments")

    await db.delete(comment)


async def upload_attachment(
    db: AsyncSession,
    household_id: str,
    entity_type: str,
    entity_id: str,
    user: User,
    file: UploadFile,
) -> AttachmentResponse:
    await require_membership(db, household_id, user.id)

    # Validate file type
    allowed_types = {"image/jpeg", "image/png", "image/gif", "image/webp", "image/heic", "application/pdf"}
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File type {file.content_type} not allowed",
        )

    # Validate file size
    max_size = settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024
    content = await file.read()
    if len(content) > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Max {settings.MAX_UPLOAD_SIZE_MB}MB",
        )

    # Save file
    ext = os.path.splitext(file.filename or "file")[1] or ".jpg"
    file_id = str(uuid.uuid4())
    rel_path = f"{household_id}/{entity_type}/{file_id}{ext}"
    full_path = os.path.join(settings.UPLOAD_DIR, rel_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)

    with open(full_path, "wb") as f:
        f.write(content)

    file_url = f"/uploads/{rel_path}"

    attachment = Attachment(
        household_id=household_id,
        entity_type=entity_type,
        entity_id=entity_id,
        user_id=user.id,
        file_url=file_url,
        file_name=file.filename or f"file{ext}",
        file_type=file.content_type or "application/octet-stream",
        file_size=len(content),
    )
    db.add(attachment)
    await db.flush()

    return AttachmentResponse(
        id=attachment.id,
        entity_type=attachment.entity_type,
        entity_id=attachment.entity_id,
        user_id=attachment.user_id,
        file_url=attachment.file_url,
        file_name=attachment.file_name,
        file_type=attachment.file_type,
        file_size=attachment.file_size,
        thumbnail_url=attachment.thumbnail_url,
        created_at=attachment.created_at,
    )


async def list_attachments(
    db: AsyncSession,
    household_id: str,
    entity_type: str,
    entity_id: str,
    user: User,
) -> list[AttachmentResponse]:
    await require_membership(db, household_id, user.id)

    result = await db.execute(
        select(Attachment).where(
            Attachment.household_id == household_id,
            Attachment.entity_type == entity_type,
            Attachment.entity_id == entity_id,
        ).order_by(Attachment.created_at.asc())
    )
    return [
        AttachmentResponse(
            id=a.id,
            entity_type=a.entity_type,
            entity_id=a.entity_id,
            user_id=a.user_id,
            file_url=a.file_url,
            file_name=a.file_name,
            file_type=a.file_type,
            file_size=a.file_size,
            thumbnail_url=a.thumbnail_url,
            created_at=a.created_at,
        )
        for a in result.scalars().all()
    ]
