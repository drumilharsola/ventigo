"""
SQLAlchemy ORM models for permanent data (users, profiles, blocked users).
Ephemeral data (rooms, messages, queues, OTPs, posts) stays in Redis.
"""

import time

from sqlalchemy import (
    Column, String, Integer, Boolean, BigInteger, ForeignKey, UniqueConstraint, Index
)
from sqlalchemy.orm import DeclarativeBase, relationship


class Base(DeclarativeBase):
    pass


_USER_SESSION_ID_FK = "users.session_id"


class User(Base):
    """Account credentials — replaces email_account:{hash}, pwd:{sid}, acct_email:{sid}, session_ehash:{sid}"""
    __tablename__ = "users"

    session_id = Column(String(64), primary_key=True)
    email_hash = Column(String(128), unique=True, nullable=False, index=True)
    email = Column(String(320), nullable=False)
    password_hash = Column(String(128), nullable=False)
    created_at = Column(BigInteger, default=lambda: int(time.time()), nullable=False)

    profile = relationship("Profile", back_populates="user", uselist=False, lazy="joined",
                            cascade="all, delete-orphan", passive_deletes=True)


class Profile(Base):
    """User profile — replaces profile:{session_id} hash and username:{name} keys."""
    __tablename__ = "profiles"

    session_id = Column(
        String(64), ForeignKey(_USER_SESSION_ID_FK, ondelete="CASCADE"), primary_key=True
    )
    username = Column(String(64), unique=True, nullable=False, index=True)
    avatar_id = Column(Integer, default=0, nullable=False)
    age_verified = Column(Boolean, default=True, nullable=False)
    email_verified = Column(Boolean, default=False, nullable=False)
    speak_count = Column(Integer, default=0, nullable=False)
    listen_count = Column(Integer, default=0, nullable=False)
    created_at = Column(BigInteger, default=lambda: int(time.time()), nullable=False)

    user = relationship("User", back_populates="profile")


class BlockedUser(Base):
    """Blocked peer — replaces blocked:{session_id} set and block_info:{sid}:{peer} hashes."""
    __tablename__ = "blocked_users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    blocker_session_id = Column(String(64), ForeignKey(_USER_SESSION_ID_FK, ondelete="CASCADE"), nullable=False)
    blocked_session_id = Column(String(64), nullable=False)
    username = Column(String(64), default="", nullable=False)
    avatar_id = Column(Integer, default=0, nullable=False)
    blocked_at = Column(BigInteger, default=lambda: int(time.time()), nullable=False)

    __table_args__ = (
        UniqueConstraint("blocker_session_id", "blocked_session_id", name="uq_block_pair"),
        Index("ix_blocker", "blocker_session_id"),
    )


class Connection(Base):
    """Saved connection between two users for direct re-chat."""
    __tablename__ = "connections"

    id = Column(Integer, primary_key=True, autoincrement=True)
    session_id_a = Column(String(64), ForeignKey(_USER_SESSION_ID_FK, ondelete="CASCADE"), nullable=False)
    session_id_b = Column(String(64), ForeignKey(_USER_SESSION_ID_FK, ondelete="CASCADE"), nullable=False)
    requested_by = Column(String(64), nullable=False)
    status = Column(String(16), default="pending", nullable=False)  # pending | accepted
    created_at = Column(BigInteger, default=lambda: int(time.time()), nullable=False)

    __table_args__ = (
        UniqueConstraint("session_id_a", "session_id_b", name="uq_connection_pair"),
        Index("ix_conn_a", "session_id_a"),
        Index("ix_conn_b", "session_id_b"),
    )
