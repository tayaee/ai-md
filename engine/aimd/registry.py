"""Dynamic sub-app registry (issue-9, issue-10 prerequisite).

Holds the `app` object from the dist/<name>.ai.md.py file, and swaps in a new
module whenever the file is updated (hot-swap). If the import fails, the
existing app is kept to guarantee availability.

ADR-0004: hot-swap-single-host-app

Threading model: the registry (1) parallelizes reloads across names via a
per-name lock (the issue-50 must-fix fix) -- a slow module load for one
sub-app does not block lookups for other sub-apps. (2) The short
_locks_guard, which protects the _locks dict itself, is only held while
creating a new lock. (3) get calls for the same name are serialized, and
drop only acquires the lock for its own name.
"""
import logging
import threading
from pathlib import Path
from typing import Any

from . import validators

log = logging.getLogger("aimd.registry")


class AppRegistry:
    """Store keyed by name (e.g. "convert.ai.md") -> (ASGI app, py mtime at load time)."""

    def __init__(self) -> None:
        self._apps: dict[str, tuple[Any, float]] = {}
        # A per-name lock, plus a short guard protecting the dict itself.
        # We only need to prevent races during _locks dict initialization --
        # once a lock exists, threading.Lock guarantees safe concurrent entry
        # to that lock itself.
        self._locks: dict[str, threading.Lock] = {}
        self._locks_guard = threading.Lock()

    def _lock_for(self, name: str) -> threading.Lock:
        """Returns the lock for a name, creating it first if it doesn't exist.

        _locks_guard is a short critical section for serializing dict updates
        -- it's released right after acquiring, so it doesn't block calls
        across different names.
        """
        lock = self._locks.get(name)
        if lock is not None:
            return lock
        with self._locks_guard:
            lock = self._locks.get(name)
            if lock is None:
                lock = threading.Lock()
                self._locks[name] = lock
            return lock

    def get(self, name: str, py_file: Path) -> Any:
        """Returns the app up to date with py_file.

        - If unregistered, or py_file.stat().st_mtime is newer than the stored
          mtime, attempt a reload
        - reload: validators.load_module(py_file) -> on success, replace with
          (module.app, mtime)
        - reload failure: log.error, then return the existing app if there is
          one, otherwise propagate the exception
        - The whole process runs inside _lock_for(name) (per-name isolation)
        """
        with self._lock_for(name):
            current_mtime = py_file.stat().st_mtime
            entry = self._apps.get(name)
            if entry is not None:
                app, saved_mtime = entry
                if saved_mtime >= current_mtime:
                    return app

            # reload -- unregistered or stale
            try:
                module = validators.load_module(py_file)
            except (Exception, SystemExit) as e:
                if entry is not None:
                    log.error("hot-swap failed for %s: %s", name, e)
                    app, _ = entry
                    return app
                raise

            app = module.app
            self._apps[name] = (app, current_mtime)
            return app

    def drop(self, name: str) -> None:
        """Deregisters (for when the py artifact has been deleted). No-op if absent."""
        with self._lock_for(name):
            self._apps.pop(name, None)
        # Leave the entry in the lock dict -- reusing the same lock object on
        # re-registration for the same name avoids a hang where a stale lock
        # holder blocks a new get (re-registration is effectively drop
        # followed by reload, and a brand-new instance arriving for the same
        # name as a drop is in practice rare).
