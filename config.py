# -------------------------------------------------------
# config.py — Centralized Configuration
#   Single source of truth for all constants used across
#   modules
#   We load from .env first and fall back to hardcoded
#   defaults so the app still runs in environments where
#   the .env file is missing (e.g. CI pipelines).
from dotenv import load_dotenv   # -- reads key=value pairs from .env into os.environ
import os

load_dotenv()   # -- must be called before any os.getenv(); populates environment from .env

# MySQL connection constants
# We use os.getenv with a fallback string so the module never raises a KeyError,
# even when the .env file is absent or incomplete.
MYSQL_HOST = os.getenv("MYSQL_HOST", "localhost")       # -- database server address
MYSQL_USER = os.getenv("MYSQL_USER", "root")            # -- database login user
MYSQL_PASS = os.getenv("MYSQL_PASS", "Ram12102002")     # -- database login password
MYSQL_DB   = os.getenv("MYSQL_DB",   "cafeteria")       # -- schema / database name

# Banxico API token
BANXICO_TOKEN = os.getenv(
    "BANXICO_TOKEN",
    "921d8e684a5de682c4b3286f15cc0e05464de846bb7f7720d7bd01d39525a3c2"   # -- fallback token
)

# File-system paths
# BASE_DIR resolves to the folder containing this very file,
# so paths stay correct regardless of where the user launches the app from.
BASE_DIR = os.path.dirname(__file__)                    # -- absolute path to the project root
DATA_DIR = os.path.join(BASE_DIR, "data")               # -- folder where all CSV outputs are saved
os.makedirs(DATA_DIR, exist_ok=True)                    # -- create /data if it does not exist yet