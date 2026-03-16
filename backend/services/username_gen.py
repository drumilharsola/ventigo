"""
Username generator - Adjective + Animal format.
e.g. SilentFox, BravePanda, WildOrca
"""

import secrets

ADJECTIVES = [
    "Silent", "Brave", "Wild", "Swift", "Calm",
    "Bold", "Keen", "Dark", "Bright", "Lone",
    "Fierce", "Gentle", "Mystic", "Noble", "Proud",
    "Rapid", "Sleek", "Stark", "Vivid", "Witty",
    "Amber", "Crisp", "Daring", "Eager", "Frosty",
    "Golden", "Hidden", "Icy", "Jolly", "Lively",
    "Mellow", "Nimble", "Odd", "Peppy", "Quirky",
    "Rustic", "Steady", "Tidy", "Urban", "Vast",
    "Wandering", "Xeric", "Yonder", "Zesty", "Astral",
    "Blazing", "Cobalt", "Dusk", "Electric", "Frozen",
]

ANIMALS = [
    "Fox", "Panda", "Orca", "Wolf", "Hawk",
    "Bear", "Lynx", "Crow", "Deer", "Elk",
    "Falcon", "Gecko", "Hare", "Ibis", "Jaguar",
    "Kite", "Lemur", "Mink", "Newt", "Owl",
    "Puma", "Quail", "Raven", "Seal", "Tiger",
    "Urial", "Viper", "Wren", "Xerus", "Yak",
    "Zebra", "Ape", "Bison", "Crane", "Drake",
    "Eagle", "Finch", "Gnu", "Heron", "Impala",
    "Jackal", "Koala", "Llama", "Mole", "Narwhal",
    "Ocelot", "Pelican", "Quokka", "Robin", "Stork",
]


def generate_username() -> str:
    adjective = secrets.choice(ADJECTIVES)
    animal = secrets.choice(ANIMALS)
    return f"{adjective}{animal}"


async def generate_unique_username(redis=None) -> str:
    """Generate a username not currently in use (checks Postgres profiles table)."""
    from sqlalchemy import select
    from db.postgres_client import get_session_factory
    from db.models import Profile

    factory = get_session_factory()
    for _ in range(20):
        username = generate_username()
        async with factory() as db:
            result = await db.execute(select(Profile).where(Profile.username == username))
            if result.scalar_one_or_none() is None:
                return username
    # Fallback: append a random number if all checked are taken
    username = generate_username()
    suffix = secrets.randbelow(90) + 10
    return f"{username}{suffix}"
