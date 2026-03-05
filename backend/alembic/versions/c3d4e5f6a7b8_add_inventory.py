"""add inventory items table

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-03-04 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'c3d4e5f6a7b8'
down_revision: Union[str, None] = 'b2c3d4e5f6a7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('inventory_items',
        sa.Column('id', sa.UUID(as_uuid=False), nullable=False),
        sa.Column('household_id', sa.UUID(as_uuid=False), nullable=False),
        sa.Column('name', sa.String(length=200), nullable=False),
        sa.Column('quantity', sa.Float(), nullable=True),
        sa.Column('unit', sa.String(length=30), nullable=True),
        sa.Column('category', sa.String(length=30), server_default='other', nullable=False),
        sa.Column('barcode', sa.String(length=50), nullable=True),
        sa.Column('expiry_date', sa.Date(), nullable=True),
        sa.Column('location', sa.String(length=20), server_default='pantry', nullable=False),
        sa.Column('added_by', sa.UUID(as_uuid=False), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_inventory_items_household_id'), 'inventory_items', ['household_id'], unique=False)
    op.create_index(op.f('ix_inventory_items_barcode'), 'inventory_items', ['barcode'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_inventory_items_barcode'), table_name='inventory_items')
    op.drop_index(op.f('ix_inventory_items_household_id'), table_name='inventory_items')
    op.drop_table('inventory_items')
