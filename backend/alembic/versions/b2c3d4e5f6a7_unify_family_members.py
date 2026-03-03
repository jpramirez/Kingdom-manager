"""unify family members: add invite_email, invite_phone, is_admin to family_profiles + backfill

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-02-27 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'b2c3d4e5f6a7'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add new columns to family_profiles
    op.add_column('family_profiles', sa.Column('invite_email', sa.String(255), nullable=True))
    op.add_column('family_profiles', sa.Column('invite_phone', sa.String(20), nullable=True))
    op.add_column('family_profiles', sa.Column('is_admin', sa.Boolean(), nullable=False, server_default='false'))

    # Backfill: create a FamilyProfile for every HouseholdMember that has no linked profile yet
    op.execute("""
        INSERT INTO family_profiles (
            id, household_id, name, role, preferred_lang,
            linked_user_id, linked_member_id, created_by,
            is_admin, created_at, updated_at
        )
        SELECT
            gen_random_uuid(),
            hm.household_id,
            COALESCE(u.display_name, 'Unknown'),
            hm.role,
            COALESCE(u.preferred_locale, 'en'),
            hm.user_id,
            hm.id,
            hm.user_id,
            hm.is_admin,
            hm.joined_at,
            hm.joined_at
        FROM household_members hm
        JOIN users u ON u.id = hm.user_id
        WHERE NOT EXISTS (
            SELECT 1 FROM family_profiles fp
            WHERE fp.linked_member_id = hm.id
        )
    """)


def downgrade() -> None:
    op.drop_column('family_profiles', 'is_admin')
    op.drop_column('family_profiles', 'invite_phone')
    op.drop_column('family_profiles', 'invite_email')
