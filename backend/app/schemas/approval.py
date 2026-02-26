from datetime import datetime

from pydantic import BaseModel, Field


class ApprovalCreateRequest(BaseModel):
    request_type: str = Field(pattern=r"^(grocery_purchase|schedule_change|member_join|other)$")
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    reference_id: str | None = None
    reference_type: str | None = None


class ApprovalDecisionRequest(BaseModel):
    reason: str | None = None


class ApprovalResponse(BaseModel):
    id: str
    household_id: str
    requested_by: str
    approved_by: str | None = None
    request_type: str
    title: str
    description: str | None = None
    reference_id: str | None = None
    reference_type: str | None = None
    status: str
    decided_at: datetime | None = None
    created_at: datetime
    requester_name: str | None = None
    approver_name: str | None = None

    model_config = {"from_attributes": True}
