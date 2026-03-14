"""connections table

Revision ID: 002
Revises: 001
Create Date: 2026-03-14
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "connections",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("session_id_a", sa.String(64), sa.ForeignKey("users.session_id", ondelete="CASCADE"), nullable=False),
        sa.Column("session_id_b", sa.String(64), sa.ForeignKey("users.session_id", ondelete="CASCADE"), nullable=False),
        sa.Column("requested_by", sa.String(64), nullable=False),
        sa.Column("status", sa.String(16), default="pending", nullable=False),
        sa.Column("created_at", sa.BigInteger, nullable=False),
        sa.UniqueConstraint("session_id_a", "session_id_b", name="uq_connection_pair"),
    )
    op.create_index("ix_conn_a", "connections", ["session_id_a"])
    op.create_index("ix_conn_b", "connections", ["session_id_b"])


def downgrade() -> None:
    op.drop_table("connections")
