# /// script
# requires-python = ">=3.10"
# dependencies = ["openreview-py==2.9.1"]
# ///
"""Run in your own terminal: uv run scripts/openreview/probe.py

Read-only public-paper probe; login is the only account operation. No credentials
or sessions are saved. TOTP is supported; email/passkey MFA is intentionally not.
"""

from __future__ import annotations

import getpass
import json
import logging
import os
import re
import sys
import warnings
from typing import Any
from urllib.parse import urljoin, urlsplit

import openreview
import openreview.api
import requests
from requests.adapters import HTTPAdapter


API_V1: str = "https://api.openreview.net"
API_V2: str = "https://api2.openreview.net"
# Live routing must still be confirmed by the user's authenticated run. Never
# switch APIs on an access error or browser challenge.
TARGETS: tuple[tuple[str, str, str], ...] = (
    ("NodePiece", "xMJWUKJnFSw", API_V1),
    ("Reasoning on Graphs", "ZGNWW7xZ6Q", API_V2),
)


class ProbeError(Exception):
    """Contains only a fixed, credential-free diagnostic."""


class BoundedAdapter(HTTPAdapter):
    """Configure the official clients' exposed requests sessions before login."""

    def __init__(self) -> None:
        super().__init__(max_retries=0)

    def send(self, request: requests.PreparedRequest, **kwargs: Any) -> requests.Response:
        url = urlsplit(request.url or "")
        allowed = (
            request.method == "GET"
            and url.path == "/notes"
            and f"https://{url.netloc}" in (API_V1, API_V2)
        ) or (
            request.method == "POST"
            and f"https://{url.netloc}" == API_V2
            and url.path in ("/login", "/mfa/verify")
        )
        if url.scheme != "https" or not allowed:
            raise ProbeError("Refused an unexpected endpoint or account operation.")
        # 2.9.1 has no client timeout parameter. Requests' adapter hook supplies
        # connect/read inactivity limits, without timing out human input.
        kwargs["timeout"] = (10, 30)
        response = super().send(request, **kwargs)
        status = response.status_code
        content_type = response.headers.get("Content-Type", "").lower()
        message = None
        if 300 <= status < 400:
            message = "Redirect refused; complete any browser verification on openreview.net separately."
        elif status == 401 or (request.method == "POST" and status in (400, 422)):
            message = "Authentication/MFA rejected or session expired; no automatic retry."
        elif status == 403:
            message = "Access denied or browser verification required; check openreview.net separately."
        elif status == 404:
            message = "Note or endpoint not found on the selected API route."
        elif status == 429:
            message = "Rate limited; no automatic retry. Try again later."
        elif status >= 400:
            message = "OpenReview service rejected the request; no automatic retry."
        elif "application/json" not in content_type:
            message = "Non-JSON service/browser-verification response; check openreview.net separately."
        if message:
            response.close()
            raise ProbeError(message)
        return response


def configure_session(client: openreview.Client | openreview.api.OpenReviewClient) -> None:
    # Remove every default mount, including v2's longer-prefix edit adapters:
    # official LogRetry can print response bodies, and must never run here.
    for adapter in client.session.adapters.values():
        adapter.close()
    client.session.adapters.clear()
    client.session.mount("https://", BoundedAdapter())
    client.session.trust_env = False  # No .netrc credentials or environment proxies.
    client.session.max_redirects = 0


def hidden_input(prompt: str) -> str:
    with warnings.catch_warnings():
        warnings.simplefilter("error", getpass.GetPassWarning)
        value = getpass.getpass(prompt, stream=sys.stderr)
    if not value:
        raise ProbeError("Empty input; cancelled without retry.")
    return value


def hidden_totp(method: str) -> str:
    if method != "totp":
        raise ProbeError("Unsupported MFA method; use the OpenReview website instead.")
    code = hidden_input("Authenticator app code (hidden): ").strip()
    if not re.fullmatch(r"[0-9]{6}", code):
        raise ProbeError("Expected a six-digit authenticator code; no automatic retry.")
    return code


def content_value(content: dict[str, Any], key: str) -> Any:
    value = content.get(key)
    # API v1 uses flat fields; API v2 wraps each field in {"value": ...}.
    return value.get("value") if isinstance(value, dict) else value


def paper_metadata(note: openreview.Note | openreview.api.Note, note_id: str) -> dict[str, Any]:
    if note.id != note_id or not isinstance(note.content, dict):
        raise ProbeError("Invalid note ID or content returned by the selected API.")
    content = note.content
    title = content_value(content, "title")
    authors = content_value(content, "authors")
    if not isinstance(title, str) or not title.strip() or not isinstance(authors, list):
        raise ProbeError("Missing or invalid title/authors in the selected note.")
    # Current v2 also supports unified author objects. Never expose authorids,
    # email addresses, readers, or other unrequested note/profile fields.
    names = [author.get("fullname") if isinstance(author, dict) else author for author in authors]
    if not names or not all(isinstance(name, str) and name.strip() for name in names):
        raise ProbeError("Missing or invalid author display names.")
    venue = content_value(content, "venue") or content_value(content, "venueid")
    bibtex = content_value(content, "_bibtex")
    year = content_value(content, "year")
    pdf = content_value(content, "pdf")
    for value in (venue, bibtex, pdf):
        if value is not None and not isinstance(value, str):
            raise ProbeError("Invalid venue, PDF, or official BibTeX metadata.")
    if year is not None and (isinstance(year, bool) or not re.fullmatch(r"[0-9]{4}", str(year))):
        raise ProbeError("Invalid year metadata.")
    if year is None and bibtex:
        match = re.search(r'\byear\s*=\s*[{"]?([0-9]{4})\s*[}",]', bibtex, re.IGNORECASE)
        if match:
            year = match.group(1)
    if pdf:
        pdf = urljoin("https://openreview.net", pdf)
        url = urlsplit(pdf)
        if url.scheme != "https" or url.netloc != "openreview.net" or not url.path.startswith("/pdf"):
            raise ProbeError("Unexpected PDF location in note metadata.")
    return {
        "title": title,
        "authors": names,
        "venue": venue,
        "year": str(year) if year is not None else None,
        "pdf": pdf,
        "official_bibtex": bibtex or None,  # Never generate a citation.
    }


def main() -> int:
    clients: list[openreview.Client | openreview.api.OpenReviewClient] = []
    stage = "terminal preflight"
    previous_logging_level = logging.root.manager.disable
    try:
        if len(sys.argv) != 1:
            raise ProbeError("No arguments accepted. Enter credentials only at the hidden terminal prompts.")
        if not all(os.isatty(stream.fileno()) for stream in (sys.stdin, sys.stdout, sys.stderr)):
            raise ProbeError(
                "A real terminal is required for stdin/stdout/stderr. "
                "Run directly, without pipes or redirection."
            )
        if {"OPENREVIEW_USERNAME", "OPENREVIEW_PASSWORD", "OPENREVIEW_TOKEN"}.intersection(os.environ):
            raise ProbeError(
                "Unset OPENREVIEW_USERNAME, OPENREVIEW_PASSWORD, and OPENREVIEW_TOKEN; "
                "use hidden prompts only."
            )
        # Constructors otherwise silently load credentials from the environment.
        # With those keys absent, no constructor request occurs before setup.
        v2 = openreview.api.OpenReviewClient(baseurl=API_V2)
        clients.append(v2)
        v1 = openreview.Client(baseurl=API_V1)
        clients.append(v1)
        for client in clients:
            configure_session(client)

        username = hidden_input("OpenReview email/username (hidden): ").strip()
        if not username:
            raise ProbeError("Empty username; cancelled without retry.")
        password = hidden_input("OpenReview password (hidden): ")
        stage = "login (API v2: api2.openreview.net)"
        # Suppress dependency debug logs during requests. All diagnostics below
        # are fixed strings; never print exceptions, responses, or client objects.
        logging.disable(logging.CRITICAL)
        # Pinned 2.9.1 invokes the public TOTP provider before checking this hook.
        # Disable its visible/email/browser fallback only for this login.
        original_interactive = openreview.mfa._is_interactive
        openreview.mfa._is_interactive = lambda: False
        try:
            v2.login_user(username, password, expiresIn=3600, mfa_code_provider=hidden_totp)
        finally:
            openreview.mfa._is_interactive = original_interactive
            del password, username
        if not v2.token or not v2.profile or not v2.headers.get("Authorization"):
            raise ProbeError("Login did not establish an authenticated session.")
        # Official 2.9.1 tools.py reuses client.token across v1/v2 clients. Assign
        # after construction to avoid its automatic profile lookup before setup.
        v1.token = v2.token
        v1.headers["Authorization"] = v2.headers["Authorization"]
        print("Login succeeded (API v2). Session is held only in this process.", flush=True)
        print(
            "Retrieving public notes; success does not prove private-note access. Missing metadata is null.",
            flush=True,
        )
        for label, note_id, route in TARGETS:
            version = "v1" if route == API_V1 else "v2"
            stage = f"{label} {note_id} (API {version}: {urlsplit(route).netloc})"
            note = (v1 if route == API_V1 else v2).get_note(note_id)
            metadata = paper_metadata(note, note_id)
            print(f"\nPublic note retrieved: {label} {note_id} (API {version})")
            # JSON escaping prevents server-provided text from injecting terminal
            # controls. Only allowlisted bibliographic fields leave the process.
            print(json.dumps(metadata, ensure_ascii=True, indent=2), flush=True)
        return 0
    except (KeyboardInterrupt, EOFError):
        print("\nCancelled; no automatic retry.", file=sys.stderr)
        return 130
    except getpass.GetPassWarning:
        print("Hidden terminal input unavailable; refused to echo credentials.", file=sys.stderr)
        return 1
    except openreview.OpenReviewException as error:
        detail = error.args[0] if error.args else None
        if isinstance(error, openreview.MfaRequiredException) or (
            isinstance(detail, dict) and detail.get("name") == "MfaError"
        ):
            print(
                f"{stage}: MFA unsupported or failed (including email/passkey). Use openreview.net in a browser; "
                "this probe supports authenticator-app codes only. Do not disable account MFA.",
                file=sys.stderr,
            )
        else:
            print(
                f"{stage}: OpenReview rejected the operation; details suppressed. No automatic retry.",
                file=sys.stderr,
            )
        return 1
    except requests.exceptions.Timeout:
        print(f"{stage}: request timed out; no automatic retry.", file=sys.stderr)
        return 1
    except requests.exceptions.ConnectionError:
        print(f"{stage}: network/TLS connection failed; no automatic retry.", file=sys.stderr)
        return 1
    except ProbeError as error:
        print(f"{stage}: {error}", file=sys.stderr)
        return 1
    except (ValueError, KeyError, IndexError, TypeError, AttributeError):
        print(f"{stage}: invalid or missing OpenReview response data; no automatic retry.", file=sys.stderr)
        return 1
    except Exception:
        print(
            f"{stage}: OpenReview/client failure; details suppressed to protect credentials. No automatic retry.",
            file=sys.stderr,
        )
        return 1
    finally:
        for client in clients:
            client.session.close()
            client.headers.clear()
            client.token = client.profile = client.user = None
        logging.disable(previous_logging_level)


if __name__ == "__main__":
    raise SystemExit(main())
