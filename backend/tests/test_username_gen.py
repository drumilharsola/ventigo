"""Tests for services/username_gen.py."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from services.username_gen import generate_username, generate_unique_username, ADJECTIVES, ANIMALS


def test_generate_username_format():
    name = generate_username()
    assert isinstance(name, str)
    assert len(name) > 2


def test_generate_username_components():
    """Username must be Adjective + Animal from the known lists."""
    for _ in range(50):
        name = generate_username()
        found = False
        for adj in ADJECTIVES:
            if name.startswith(adj):
                animal_part = name[len(adj):]
                if animal_part in ANIMALS:
                    found = True
                    break
        assert found, f"Username {name} does not match Adjective+Animal pattern"


def test_generate_username_randomness():
    """Multiple calls should produce at least some different names."""
    names = {generate_username() for _ in range(20)}
    assert len(names) > 1


@pytest.mark.asyncio
async def test_generate_unique_username_first_try():
    """When DB has no collision, returns the first generated name."""
    mock_factory = MagicMock()
    mock_session = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_session.execute = AsyncMock(return_value=mock_result)
    mock_session.__aenter__ = AsyncMock(return_value=mock_session)
    mock_session.__aexit__ = AsyncMock(return_value=False)
    mock_factory.return_value = mock_session

    with patch("db.postgres_client.get_session_factory", return_value=mock_factory):
        result = await generate_unique_username()
        assert isinstance(result, str)
        assert len(result) > 2


@pytest.mark.asyncio
async def test_generate_unique_username_with_collisions():
    """After 20 collisions, falls back to name + suffix."""
    mock_factory = MagicMock()
    mock_session = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = "taken"
    mock_session.execute = AsyncMock(return_value=mock_result)
    mock_session.__aenter__ = AsyncMock(return_value=mock_session)
    mock_session.__aexit__ = AsyncMock(return_value=False)
    mock_factory.return_value = mock_session

    with patch("db.postgres_client.get_session_factory", return_value=mock_factory):
        result = await generate_unique_username()
        assert any(c.isdigit() for c in result)


def test_adjectives_list_not_empty():
    assert len(ADJECTIVES) > 0


def test_animals_list_not_empty():
    assert len(ANIMALS) > 0
