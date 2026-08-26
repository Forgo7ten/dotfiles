from pathlib import Path
import idaapi

'''
~/.idapro/idapythonrc.py
'''

def activate_virtualenv(virtualenv_path: Path):
    for bindir in ("Scripts", "bin"):
        activate_this_path = virtualenv_path / bindir / "activate_this.py"

        if not activate_this_path.exists():
            continue

        if not activate_this_path.is_file():
            continue

        exec(activate_this_path.read_text(), dict(__file__=str(activate_this_path)))
        print("[idapythonrc.py] Activated virtual environment: " + str(virtualenv_path))
        break

    else:
        raise ValueError('Could not find "activate_this.py" in ' + str(virtualenv_path))


IDAUSR = Path(idaapi.get_user_idadir())
activate_virtualenv(IDAUSR / "venv")
