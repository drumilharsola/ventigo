"""
Username generator - Adjective + Animal format.
e.g. SilentFox, BravePanda, WildOrca
"""

import random

from db.redis_client import tenant_key

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
    adjective = random.choice(ADJECTIVES)
    animal = random.choice(ANIMALS)
    return f"{adjective}{animal}"


async def generate_unique_username(redis, tid: str = "default") -> str:
    """Generate a username not currently in use by an active session."""
    for _ in range(20):
        username = generate_username()
        key = tenant_key(tid, f"username:{username}")
        if not await redis.exists(key):
            return username
    username = generate_username()
    suffix = random.randint(10, 99)
    return f"{username}{suffix}"


async def reserve_username(redis, username: str, session_id: str, tid: str = "default") -> None:
    """Persist the username -> session mapping for stable profile lookups."""
    await redis.set(tenant_key(tid, f"username:{username}"), session_id)


async def release_username(redis, username: str, tid: str = "default") -> None:
    """Free username when session ends."""
    await redis.delete(tenant_key(tid, f"username:{username}"))
