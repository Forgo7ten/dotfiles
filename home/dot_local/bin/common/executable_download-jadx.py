#!/usr/bin/env python3
"""
Download the latest jadx release from GitHub
"""

import os
import sys
import json
import shutil
import zipfile
import re
import hashlib
import stat
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError


def get_install_path():
    """Get the installation path from environment variable or command line argument"""
    # Priority 1: Command line argument
    if len(sys.argv) > 1:
        return Path(sys.argv[1])

    # Priority 2: Environment variable
    jadx_home = os.environ.get("JADX_HOME")
    if jadx_home:
        return Path(jadx_home)

    # No path provided
    print("Error: No installation path provided.")
    print("Please set JADX_HOME environment variable or provide path as argument.")
    print(f"Usage: {sys.argv[0]} [install_path]")
    sys.exit(1)


def get_github_headers():
    """Get headers for GitHub API requests, including token if available"""
    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "jadx-downloader",
    }

    github_token = os.environ.get("GITHUB_TOKEN")
    if github_token:
        headers["Authorization"] = f"token {github_token}"
        print("Using GitHub token for API requests")

    return headers


def get_latest_release():
    """Get the latest release information from GitHub API"""
    api_url = "https://api.github.com/repos/skylot/jadx/releases/latest"

    try:
        req = Request(api_url, headers=get_github_headers())
        with urlopen(req) as response:
            data = json.loads(response.read().decode("utf-8"))
            return data
    except HTTPError as e:
        print(f"HTTP Error: {e.code} - {e.reason}")
        sys.exit(1)
    except URLError as e:
        print(f"URL Error: {e.reason}")
        sys.exit(1)
    except Exception as e:
        print(f"Error fetching release info: {e}")
        sys.exit(1)


def get_current_version(install_path):
    """Get currently installed version from version file"""
    version_file = install_path / ".version"
    if version_file.exists():
        try:
            return version_file.read_text().strip()
        except Exception:
            return None
    return None


def save_version(install_path, version):
    """Save version information to file"""
    version_file = install_path / ".version"
    try:
        version_file.write_text(version)
    except Exception as e:
        print(f"Warning: Could not save version info: {e}")


def calculate_sha256(file_path):
    """Calculate SHA256 hash of a file"""
    sha256_hash = hashlib.sha256()
    try:
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                sha256_hash.update(chunk)
        return sha256_hash.hexdigest()
    except Exception as e:
        print(f"Error calculating SHA256: {e}")
        return None


def download_file(url, dest_path, filename, expected_size):
    """Download file with progress bar and integrity check"""
    try:
        req = Request(url, headers=get_github_headers())
        with urlopen(req) as response:
            total_size = int(response.headers.get("Content-Length", 0))

            # Verify expected size matches
            if expected_size > 0 and total_size > 0 and total_size != expected_size:
                print(
                    f"\nWarning: Expected size {expected_size} doesn't match Content-Length {total_size}"
                )

            print(f"Downloading {filename}...")
            print(f"Size: {total_size / 1024 / 1024:.2f} MB")

            downloaded = 0
            block_size = 8192

            with open(dest_path, "wb") as f:
                while True:
                    try:
                        chunk = response.read(block_size)
                        if not chunk:
                            break

                        f.write(chunk)
                        downloaded += len(chunk)

                        # Show progress
                        if total_size > 0:
                            progress = downloaded / total_size * 100
                            bar_length = 50
                            filled = int(bar_length * downloaded / total_size)
                            bar = "=" * filled + "-" * (bar_length - filled)
                            print(
                                f"\r[{bar}] {progress:.1f}% ({downloaded / 1024 / 1024:.2f} MB)",
                                end="",
                                flush=True,
                            )
                    except Exception as e:
                        print(f"\n\nError during download: {e}")
                        # Remove incomplete file
                        if dest_path.exists():
                            dest_path.unlink()
                        return False

            print()  # New line after progress bar

            # Verify download completeness
            if total_size > 0 and downloaded != total_size:
                print(
                    f"Error: Download incomplete! Expected {total_size} bytes, got {downloaded} bytes"
                )
                # Remove incomplete file
                if dest_path.exists():
                    dest_path.unlink()
                return False

            # Verify file actually exists and has correct size
            if not dest_path.exists():
                print("Error: Downloaded file does not exist!")
                return False

            actual_size = dest_path.stat().st_size
            if actual_size != downloaded:
                print(
                    f"Error: File size mismatch! Downloaded {downloaded} bytes, but file is {actual_size} bytes"
                )
                dest_path.unlink()
                return False

            print(f"Download completed: {dest_path}")
            print(f"File size verified: {actual_size / 1024 / 1024:.2f} MB")
            return True

    except KeyboardInterrupt:
        print("\n\nDownload interrupted by user")
        # Clean up incomplete file
        if dest_path.exists():
            dest_path.unlink()
        sys.exit(1)
    except Exception as e:
        print(f"\nError downloading file: {e}")
        # Clean up incomplete file
        if dest_path.exists():
            dest_path.unlink()
        return False


def verify_zip_file(zip_path, expected_size, expected_sha256=None):
    """Verify that the zip file exists, is valid, and has correct size and hash"""
    try:
        # Check file exists
        if not zip_path.exists():
            print(f"Error: File does not exist: {zip_path}")
            return False

        # Check file size
        actual_size = zip_path.stat().st_size
        if actual_size == 0:
            print("Error: Downloaded file is empty!")
            return False

        if expected_size > 0 and actual_size != expected_size:
            print(f"Error: File size mismatch!")
            print(f"  Expected: {expected_size / 1024 / 1024:.2f} MB")
            print(f"  Actual:   {actual_size / 1024 / 1024:.2f} MB")
            return False

        # Verify SHA256 hash if provided
        if expected_sha256:
            print("Calculating SHA256 hash...")
            actual_sha256 = calculate_sha256(zip_path)
            if not actual_sha256:
                print("Error: Could not calculate file hash")
                return False

            # GitHub API returns hash with "sha256:" prefix in some cases
            expected_hash = expected_sha256.replace("sha256:", "").lower()
            actual_hash = actual_sha256.lower()

            if actual_hash != expected_hash:
                print(f"Error: SHA256 hash mismatch!")
                print(f"  Expected: {expected_hash}")
                print(f"  Actual:   {actual_hash}")
                return False
            print(f"SHA256 verified: {actual_hash}")

        # Verify it's a valid zip file
        print("Verifying zip file integrity...")
        try:
            with zipfile.ZipFile(zip_path, "r") as zip_ref:
                # Test the zip file
                corrupt_file = zip_ref.testzip()
                if corrupt_file is not None:
                    print(
                        f"Error: Zip file is corrupted! First bad file: {corrupt_file}"
                    )
                    return False
            print("Zip file verification passed")
            return True
        except zipfile.BadZipFile:
            print("Error: File is not a valid zip file or is corrupted!")
            return False

    except Exception as e:
        print(f"Error verifying file: {e}")
        return False


def extract_zip(zip_path, extract_to):
    """Extract zip file to destination"""
    try:
        print(f"Extracting {zip_path.name}...")
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            zip_ref.extractall(extract_to)
        print(f"Extracted to: {extract_to}")
        return True
    except Exception as e:
        print(f"Error extracting zip: {e}")
        return False


def set_executable_permissions(install_path, executable_files):
    """
    Set executable permissions for specified files.

    Args:
        install_path: Base installation directory
        executable_files: List of relative paths to files that need executable permission
    """
    print("\nSetting executable permissions...")
    success_count = 0

    for relative_path in executable_files:
        file_path = install_path / relative_path

        if not file_path.exists():
            print(f"  Warning: File not found: {relative_path}")
            continue

        try:
            # Get current permissions
            current_permissions = file_path.stat().st_mode

            # Add executable permission for user, group, and others
            # stat.S_IXUSR (user execute), stat.S_IXGRP (group execute), stat.S_IXOTH (others execute)
            new_permissions = current_permissions | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH

            # Set the new permissions
            os.chmod(file_path, new_permissions)

            print(f"  ✓ Set executable: {relative_path}")
            success_count += 1
        except Exception as e:
            print(f"  ✗ Failed to set executable for {relative_path}: {e}")

    print(f"Set executable permissions for {success_count}/{len(executable_files)} files")
    return success_count == len(executable_files)


def main():
    # Get installation path
    install_path = get_install_path()
    print(f"Installation path: {install_path}")

    # Get latest release info
    print("Fetching latest release information...")
    release_data = get_latest_release()

    latest_version = release_data["tag_name"]
    print(f"Latest version: {latest_version}")

    # Check current version
    current_version = get_current_version(install_path)
    if current_version:
        print(f"Current version: {current_version}")
        if current_version == latest_version:
            print("Already up to date!")
            return
    else:
        print("No existing installation found")

    # Find the jadx-x.x.x.zip asset (not the GUI or JRE versions)
    assets = release_data.get("assets", [])
    jadx_asset = None

    # Pattern to match: jadx-x.x.x.zip (but not jadx-gui-*)
    pattern = re.compile(r"^jadx-[\d.]+(\.zip)$")

    for asset in assets:
        asset_name = asset["name"]
        if pattern.match(asset_name):
            jadx_asset = asset
            break

    if not jadx_asset:
        print("Error: Could not find jadx zip file in release assets")
        sys.exit(1)

    download_url = jadx_asset["browser_download_url"]
    filename = jadx_asset["name"]
    expected_size = jadx_asset.get("size", 0)
    expected_sha256 = jadx_asset.get("digest", None)

    print(f"Found asset: {filename}")
    if expected_size > 0:
        print(f"Expected size: {expected_size / 1024 / 1024:.2f} MB")
    if expected_sha256:
        print(f"Expected SHA256: {expected_sha256}")

    # Create temporary download directory
    temp_dir = Path("/tmp/jadx_download")
    temp_dir.mkdir(parents=True, exist_ok=True)

    zip_path = temp_dir / filename

    # Download the file
    if not download_file(download_url, zip_path, filename, expected_size):
        print("Download failed!")
        sys.exit(1)

    # Verify the downloaded file before proceeding
    if not verify_zip_file(zip_path, expected_size, expected_sha256):
        print("Downloaded file verification failed!")
        sys.exit(1)

    # Delete existing installation
    if install_path.exists():
        print(f"Removing existing installation at {install_path}...")
        try:
            shutil.rmtree(install_path)
            print("Removed successfully")
        except Exception as e:
            print(f"Error removing existing installation: {e}")
            sys.exit(1)

    # Create installation directory
    install_path.mkdir(parents=True, exist_ok=True)

    # Extract the zip file directly to install_path
    if not extract_zip(zip_path, install_path):
        print("Extraction failed!")
        sys.exit(1)

    # Check if ZIP extracted to a single subdirectory (e.g., jadx-1.4.7/)
    # If so, move its contents up one level to install_path
    extracted_items = list(install_path.iterdir())

    if len(extracted_items) == 1 and extracted_items[0].is_dir():
        # Single folder extracted (typical case: install_path/jadx-1.4.7/)
        nested_folder = extracted_items[0]
        print(f"Flattening nested directory: {nested_folder.name}")

        # Move all contents from nested folder to install_path
        for item in nested_folder.iterdir():
            item.rename(install_path / item.name)

        # Remove the now-empty nested folder
        nested_folder.rmdir()
        print(f"Installation structure normalized")

    # Save version info
    save_version(install_path, latest_version)

    # Set executable permissions for binary files
    executable_files = ["bin/jadx", "bin/jadx-gui"]
    set_executable_permissions(install_path, executable_files)

    # Clean up
    print("Cleaning up temporary files...")
    try:
        zip_path.unlink()
    except Exception as e:
        print(f"Warning: Could not remove temp file: {e}")

    print(f"\n✓ Successfully installed jadx {latest_version} to {install_path}")
    print(f"You can run it with: {install_path}/bin/jadx")


if __name__ == "__main__":
    main()
