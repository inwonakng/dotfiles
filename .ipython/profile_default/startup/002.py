from IPython import get_ipython
from prompt_toolkit.clipboard.pyperclip import PyperclipClipboard
ip = get_ipython()
if getattr(ip, "pt_app", None):
    ip.pt_app.clipboard = PyperclipClipboard()
