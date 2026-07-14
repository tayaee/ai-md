import logging
import threading
import time
from pathlib import Path
from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from . import compiler
from .config import Settings

log = logging.getLogger("aimd.watcher")

_DEBOUNCE_SECONDS = 0.5


class _SpecEventHandler(FileSystemEventHandler):
    """Handles only *.ai.md files among created/modified events."""

    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.settings = settings
        self._last_times: dict[str, float] = {}
        self._lock = threading.Lock()

    def _should_handle(self, event) -> bool:
        if event.is_directory:
            return False
        # Check whether the file ends with *.ai.md
        return event.src_path.endswith(".ai.md")

    def on_created(self, event) -> None:
        self._handle_event(event)

    def on_modified(self, event) -> None:
        self._handle_event(event)

    def _handle_event(self, event) -> None:
        if not self._should_handle(event):
            return

        name = Path(event.src_path).name
        now = time.time()

        with self._lock:
            last_time = self._last_times.get(name, 0.0)
            if now - last_time < _DEBOUNCE_SECONDS:
                return
            self._last_times[name] = now

        threading.Thread(target=self._compile, args=(name,), daemon=True).start()

    def _compile(self, name: str) -> None:
        try:
            compiler.compile_spec(name, self.settings)
        except Exception as e:
            log.error("background compile failed for %s: %s", name, e)


def start_watcher(settings: Settings) -> Observer:
    """Creates an Observer, starts a non-recursive watch on settings.src_dir, and returns it."""
    observer = Observer()
    handler = _SpecEventHandler(settings)
    observer.schedule(handler, str(settings.src_dir), recursive=False)
    observer.start()
    return observer
