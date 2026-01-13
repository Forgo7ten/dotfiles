#!/usr/bin/env python3
"""
Download JEB from 52pojie.cn
"""

import sys
import json
import re
import gzip
import argparse
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError


def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description="Download files from 52pojie.cn",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "target_directory",
        type=str,
        help="Target directory where files will be downloaded",
    )

    parser.add_argument(
        "-p",
        "--pattern",
        type=str,
        default=None,
        help="File pattern to match (e.g., '/Tools/Android_Tools/JEB_demo_([\\d.]+)_by_CXV')",
    )

    args = parser.parse_args()
    return args


def get_file_list():
    """Fetch and parse the list.js file from 52pojie.cn"""
    list_url = "https://down.52pojie.cn/list.js"

    headers = {
        "Accept": "*/*",
        "Accept-Encoding": "gzip, deflate, br, zstd",
        "Accept-Language": "zh-CN,zh;q=0.9",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "Host": "down.52pojie.cn",
        "Pragma": "no-cache",
        "Referer": "https://down.52pojie.cn/Tools/Android_Tools/",
        "Sec-Fetch-Dest": "script",
        "Sec-Fetch-Mode": "no-cors",
        "Sec-Fetch-Site": "same-origin",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36",
        "sec-ch-ua": '"Google Chrome";v="143", "Chromium";v="143", "Not A(Brand";v="24"',
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": '"macOS"',
    }

    try:
        request = Request(list_url, headers=headers)
        with urlopen(request) as response:
            # Read raw bytes
            raw_data = response.read()

            # Check if content is gzip compressed
            # Gzip magic number is 1f 8b
            if raw_data[:2] == b"\x1f\x8b":
                # Decompress gzip data
                content = gzip.decompress(raw_data).decode("utf-8")
            else:
                # Not compressed, decode directly
                content = raw_data.decode("utf-8")

            # Extract JSON from JSONP callback
            # Format: __jsonpCallbackDown52PojieCn({...});
            jsonp_match = re.search(
                r"__jsonpCallbackDown52PojieCn\((.+)\);?\s*$", content
            )
            if not jsonp_match:
                print("Error: Could not parse JSONP response")
                sys.exit(1)

            json_content = jsonp_match.group(1)
            file_tree = json.loads(json_content)
            return file_tree

    except HTTPError as e:
        print(f"HTTP Error: {e.code} - {e.reason}")
        sys.exit(1)
    except URLError as e:
        print(f"URL Error: {e.reason}")
        sys.exit(1)
    except Exception as e:
        print(f"Error fetching list data: {e}")
        sys.exit(1)


def find_files_by_pattern(pattern):
    """
    Find files matching the given path pattern with regex support.

    Args:
        pattern: Path pattern like "/Tools/Android_Tools/JEB_demo_([\\d.]+)_by_CXV"

    Returns:
        List of tuples: [(file_url, filename, file_size, modified_time), ...]
    """
    # Get the file tree
    file_tree = get_file_list()

    # Split the pattern into path segments
    # Remove leading slash if present
    pattern = pattern.lstrip("/")
    path_segments = pattern.split("/")

    # Find matching files
    matched_files = []

    def traverse_tree(node, remaining_segments, current_path=""):
        """Recursively traverse the tree structure"""
        if not remaining_segments:
            return

        segment_pattern = remaining_segments[0]
        next_segments = remaining_segments[1:]

        # Get children from current node
        child_nodes = node.get("children", [])

        for child_node in child_nodes:
            node_name = child_node.get("name", "")

            # Check if this is the last segment (file pattern)
            if not next_segments:
                # This should be a file, not a directory
                if "children" not in child_node:
                    # Try to match the filename
                    if re.match(segment_pattern, node_name):
                        file_path = current_path + "/" + node_name
                        file_url = "https://down.52pojie.cn" + file_path
                        matched_files.append(
                            (
                                file_url,
                                node_name,
                                child_node.get("size", 0),
                                child_node.get("time", 0),
                            )
                        )
            else:
                # This should be a directory
                if "children" in child_node:
                    # Try to match the directory name
                    if re.match(segment_pattern, node_name):
                        new_path = current_path + "/" + node_name
                        traverse_tree(child_node, next_segments, new_path)

    # Start traversal from root
    traverse_tree(file_tree, path_segments, "")

    return matched_files


def download_file(file_url, save_path, filename, expected_size):
    """Download file with progress bar"""
    try:
        request = Request(file_url)
        with urlopen(request) as response:
            content_length = int(response.headers.get("Content-Length", 0))

            if (
                expected_size > 0
                and content_length > 0
                and content_length != expected_size
            ):
                print(
                    f"\nWarning: Expected size {expected_size} doesn't match Content-Length {content_length}"
                )

            print(f"Downloading {filename}...")
            print(f"Size: {content_length / 1024 / 1024:.2f} MB")

            bytes_downloaded = 0
            chunk_size = 8192

            with open(save_path, "wb") as file:
                while True:
                    try:
                        data_chunk = response.read(chunk_size)
                        if not data_chunk:
                            break

                        file.write(data_chunk)
                        bytes_downloaded += len(data_chunk)

                        # Show progress
                        if content_length > 0:
                            progress_percent = bytes_downloaded / content_length * 100
                            bar_length = 50
                            filled_length = int(
                                bar_length * bytes_downloaded / content_length
                            )
                            progress_bar = "=" * filled_length + "-" * (
                                bar_length - filled_length
                            )
                            print(
                                f"\r[{progress_bar}] {progress_percent:.1f}% ({bytes_downloaded / 1024 / 1024:.2f} MB)",
                                end="",
                                flush=True,
                            )
                    except Exception as e:
                        print(f"\n\nError during download: {e}")
                        if save_path.exists():
                            save_path.unlink()
                        return False

            print()  # New line after progress bar

            # Verify download completeness
            if content_length > 0 and bytes_downloaded != content_length:
                print(
                    f"Error: Download incomplete! Expected {content_length} bytes, got {bytes_downloaded} bytes"
                )
                if save_path.exists():
                    save_path.unlink()
                return False

            # Verify file size
            if not save_path.exists():
                print("Error: Downloaded file does not exist!")
                return False

            actual_file_size = save_path.stat().st_size
            if actual_file_size != bytes_downloaded:
                print(
                    f"Error: File size mismatch! Downloaded {bytes_downloaded} bytes, but file is {actual_file_size} bytes"
                )
                save_path.unlink()
                return False

            print(f"Download completed: {save_path}")
            print(f"File size verified: {actual_file_size / 1024 / 1024:.2f} MB")
            return True

    except KeyboardInterrupt:
        print("\n\nDownload interrupted by user")
        if save_path.exists():
            save_path.unlink()
        sys.exit(1)
    except Exception as e:
        print(f"\nError downloading file: {e}")
        if save_path.exists():
            save_path.unlink()
        return False


def download_by_pattern(pattern, target_dir):
    """
    Download files matching the pattern to the target directory.

    Args:
        pattern: Path pattern to match files (with regex support)
        target_dir: Path object where files should be downloaded

    Returns:
        True if successful, False otherwise
    """
    print("Fetching file list...")
    matched_files = find_files_by_pattern(pattern)

    if not matched_files:
        print(f"Error: No files found matching pattern: {pattern}")
        return False

    print(f"Found {len(matched_files)} matching file(s):")
    for file_url, filename, file_size, modified_time in matched_files:
        print(f"  - {filename} ({file_size / 1024 / 1024:.2f} MB)")

    # Sort by time (newest first)
    matched_files.sort(key=lambda x: x[3], reverse=True)

    # Select the newest file
    newest_file_url, newest_filename, newest_file_size, _ = matched_files[0]

    if len(matched_files) > 1:
        print(f"\nMultiple matches found. Downloading the newest: {newest_filename}")

    # Create target directory if not exists
    target_dir.mkdir(parents=True, exist_ok=True)

    # Download file directly to target directory
    output_path = target_dir / newest_filename

    # Download the file
    if not download_file(
        newest_file_url, output_path, newest_filename, newest_file_size
    ):
        print("Download failed!")
        return False

    print(f"\n✓ Successfully downloaded {newest_filename} to {output_path}")
    return True


def main():
    # Parse command line arguments
    args = parse_arguments()

    # Get target directory and pattern
    target_dir = Path(args.target_directory)
    print(f"Target directory: {target_dir}")

    # Use custom pattern if provided, otherwise use default
    if args.pattern:
        file_pattern = args.pattern
        print(f"Using custom pattern: {file_pattern}")
    else:
        # Default pattern for JEB
        file_pattern = r"/Tools/Android_Tools/JEB_demo_([\d.]+)_by_CXV"
        print(f"Using default pattern: {file_pattern}")

    # Download using the function
    success = download_by_pattern(file_pattern, target_dir)

    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
