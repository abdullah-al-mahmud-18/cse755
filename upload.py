import sys
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

BASE_DIR = Path(__file__).resolve().parent
CREDENTIALS_FILE = BASE_DIR / "client_secret.json"
TOKEN_FILE = BASE_DIR / "token.json"
CONFIG_FILE = BASE_DIR / "file_path.txt"

SCOPES = ["https://www.googleapis.com/auth/drive"]


def read_config():
    """Read local file and Drive folder paths from the config file."""
    if not CONFIG_FILE.is_file():
        raise FileNotFoundError(
            f"Configuration file not found: {CONFIG_FILE}"
        )

    config = {}

    for line_number, line in enumerate(
        CONFIG_FILE.read_text(encoding="utf-8-sig").splitlines(), start=1
    ):
        line = line.strip()

        if not line or line.startswith("#"):
            continue

        if ":" not in line:
            raise ValueError(
                f"Invalid configuration at line {line_number}: {line}"
            )

        key, value = line.split(":", 1)
        key = key.strip().lower()
        value = value.strip()

        if key not in ("local", "drive"):
            raise ValueError(
                f"Unknown configuration key at line {line_number}: {key}"
            )

        if not value:
            raise ValueError(
                f"Empty value at line {line_number}: {key}"
            )

        if key in config:
            raise ValueError(f"Duplicate configuration key: {key}")

        config[key] = value

    if "local" not in config or "drive" not in config:
        raise ValueError(
            "Configuration must contain both 'local:' and 'drive:' entries."
        )

    return config["local"], config["drive"]


def authenticate():
    """Authenticate with Google Drive using OAuth."""
    creds = None

    if TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(
            str(TOKEN_FILE), SCOPES
        )

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not CREDENTIALS_FILE.is_file():
                raise FileNotFoundError(
                    f"Missing OAuth credentials: {CREDENTIALS_FILE}"
                )

            flow = InstalledAppFlow.from_client_secrets_file(
                str(CREDENTIALS_FILE), SCOPES
            )
            creds = flow.run_local_server(port=0)

        TOKEN_FILE.write_text(creds.to_json(), encoding="utf-8")

    return build("drive", "v3", credentials=creds)


def find_folder(service, folder_name, parent_id):
    """Find exactly one folder with the given name under a parent."""
    escaped_name = (
        folder_name.replace("\\", "\\\\").replace("'", "\\'")
    )

    query = (
        f"name = '{escaped_name}' "
        "and mimeType = 'application/vnd.google-apps.folder' "
        "and trashed = false "
        f"and '{parent_id}' in parents"
    )

    folders = []
    page_token = None

    while True:
        response = service.files().list(
            q=query,
            spaces="drive",
            pageSize=100,
            pageToken=page_token,
            fields="nextPageToken, files(id, name)",
        ).execute()

        folders.extend(response.get("files", []))
        page_token = response.get("nextPageToken")

        if not page_token:
            break

    if not folders:
        raise FileNotFoundError(
            f"Google Drive folder not found: {folder_name}"
        )

    if len(folders) > 1:
        raise ValueError(
            f"Multiple folders named '{folder_name}' exist "
            "under the same parent."
        )

    return folders[0]["id"]


def resolve_folder_path(service, folder_path):
    """Resolve a path relative to the root of My Drive."""
    normalized = folder_path.replace("\\", "/").strip("/")

    if not normalized:
        return "root"

    parts = normalized.split("/")
    parent_id = "root"

    for part in parts:
        if not part or part in (".", ".."):
            raise ValueError(
                f"Invalid Google Drive folder path: {folder_path}"
            )

        parent_id = find_folder(service, part, parent_id)

    return parent_id


def upload_file(local_file, drive_folder):
    """Upload a local file to the specified Google Drive folder."""
    path = Path(local_file).expanduser().resolve()

    if not path.is_file():
        raise FileNotFoundError(f"Local file not found: {path}")

    service = authenticate()
    folder_id = resolve_folder_path(service, drive_folder)

    metadata = {
        "name": path.name,
        "parents": [folder_id],
    }

    media = MediaFileUpload(
        str(path),
        resumable=True,
    )

    uploaded = (
        service.files()
        .create(
            body=metadata,
            media_body=media,
            fields="id, name, webViewLink",
        )
        .execute()
    )

    print("Upload successful.")
    print(f"Filename: {uploaded['name']}")
    print(f"File ID: {uploaded['id']}")

    if uploaded.get("webViewLink"):
        print(f"Drive link: {uploaded['webViewLink']}")


def main():
    try:
        local_file, drive_folder = read_config()

        print(f"Local file: {local_file}")
        print(f"Drive folder: {drive_folder}")

        upload_file(local_file, drive_folder)

    except Exception as exc:
        print(f"Upload failed: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
