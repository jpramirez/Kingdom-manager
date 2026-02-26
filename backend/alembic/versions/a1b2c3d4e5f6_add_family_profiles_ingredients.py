"""add family_profiles, recipe_ingredients, meal_plan extensions

Revision ID: a1b2c3d4e5f6
Revises: 04ed8fce1de1
Create Date: 2026-02-26 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '04ed8fce1de1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # -- Family Profiles --
    op.create_table(
        'family_profiles',
        sa.Column('id', sa.UUID(as_uuid=False), nullable=False, server_default=sa.text('gen_random_uuid()')),
        sa.Column('household_id', sa.UUID(as_uuid=False), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('role', sa.String(20), nullable=False),
        sa.Column('age', sa.Integer(), nullable=True),
        sa.Column('preferred_lang', sa.String(5), nullable=False, server_default='en'),
        sa.Column('dietary_prefs', postgresql.JSONB(), nullable=True, server_default='[]'),
        sa.Column('allergies', postgresql.JSONB(), nullable=True, server_default='[]'),
        sa.Column('meal_times', postgresql.JSONB(), nullable=True, server_default='{}'),
        sa.Column('avatar_url', sa.String(500), nullable=True),
        sa.Column('linked_user_id', sa.UUID(as_uuid=False), nullable=True),
        sa.Column('linked_member_id', sa.UUID(as_uuid=False), nullable=True),
        sa.Column('created_by', sa.UUID(as_uuid=False), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['household_id'], ['households.id'], name='fk_family_profiles_household'),
    )
    op.create_index('ix_family_profiles_household_id', 'family_profiles', ['household_id'])

    # -- Recipe Ingredients --
    op.create_table(
        'recipe_ingredients',
        sa.Column('id', sa.UUID(as_uuid=False), nullable=False, server_default=sa.text('gen_random_uuid()')),
        sa.Column('recipe_id', sa.UUID(as_uuid=False), nullable=False),
        sa.Column('name', sa.String(200), nullable=False),
        sa.Column('quantity', sa.Numeric(10, 2), nullable=True),
        sa.Column('unit', sa.String(30), nullable=True),
        sa.Column('category', sa.String(30), nullable=False, server_default='other'),
        sa.Column('optional', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['recipe_id'], ['recipes.id'], name='fk_recipe_ingredients_recipe', ondelete='CASCADE'),
    )
    op.create_index('ix_recipe_ingredients_recipe_id', 'recipe_ingredients', ['recipe_id'])

    # -- Extend meal_plans --
    op.add_column('meal_plans', sa.Column('profile_id', sa.UUID(as_uuid=False), nullable=True))
    op.add_column('meal_plans', sa.Column('meal_time', sa.Time(), nullable=True))
    op.add_column('meal_plans', sa.Column('servings', sa.Integer(), nullable=True, server_default='1'))
    op.add_column('meal_plans', sa.Column('source_lang', sa.String(5), nullable=True, server_default='en'))
    op.create_foreign_key('fk_meal_plans_profile', 'meal_plans', 'family_profiles', ['profile_id'], ['id'])

    # -- Add source_lang to content tables --
    op.add_column('chores', sa.Column('source_lang', sa.String(5), nullable=True, server_default='en'))
    op.add_column('recipes', sa.Column('source_lang', sa.String(5), nullable=True, server_default='en'))
    op.add_column('grocery_items', sa.Column('source_lang', sa.String(5), nullable=True, server_default='en'))

    # -- Content Translations cache --
    op.create_table(
        'content_translations',
        sa.Column('id', sa.UUID(as_uuid=False), nullable=False, server_default=sa.text('gen_random_uuid()')),
        sa.Column('household_id', sa.UUID(as_uuid=False), nullable=False),
        sa.Column('content_hash', sa.String(64), nullable=False),
        sa.Column('source_text', sa.Text(), nullable=False),
        sa.Column('source_lang', sa.String(5), nullable=False),
        sa.Column('target_lang', sa.String(5), nullable=False),
        sa.Column('translated_text', sa.Text(), nullable=False),
        sa.Column('model_used', sa.String(50), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_translations_household', 'content_translations', ['household_id'])
    op.create_index(
        'uq_translation_lookup',
        'content_translations',
        ['household_id', 'content_hash', 'target_lang'],
        unique=True,
    )


def downgrade() -> None:
    op.drop_table('content_translations')
    op.drop_column('grocery_items', 'source_lang')
    op.drop_column('recipes', 'source_lang')
    op.drop_column('chores', 'source_lang')
    op.drop_constraint('fk_meal_plans_profile', 'meal_plans', type_='foreignkey')
    op.drop_column('meal_plans', 'source_lang')
    op.drop_column('meal_plans', 'servings')
    op.drop_column('meal_plans', 'meal_time')
    op.drop_column('meal_plans', 'profile_id')
    op.drop_table('recipe_ingredients')
    op.drop_table('family_profiles')
