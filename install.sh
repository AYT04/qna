#!/usr/bin/env bash

#set -euo pipefail

# community.sh
# Bootstrap a minimal Flask-based Quora-style starter.
# The app stores posts in a JSON file and exposes them at root-level paths
# such as http://localhost:5000/what-year-did-canada-become-a-country.
#
# Flask docs (up to date): https://flask.palletsprojects.com/en/latest/
#
# This script generates app.py, templates/index.html, templates/post.html,
# requirements.txt, and a starter README.

print_help() {
  cat <<'EOF'
Usage: sh community.sh init [dir]

Creates a minimal Flask app for a Quora-like Question & Answer platform.

Commands:
  init [dir]   Create the project in the current directory or [dir].
  help         Show this help text.

After initialization:
  cd [dir]
  python3 -m venv venv
  source venv/bin/activate
  pip install -r requirements.txt
  python app.py

The app uses root-level slugs for posts: /<slug>
Example: http://localhost:5000/how-old-is-canada

Flask documentation: https://flask.palletsprojects.com/en/latest/

Kill Localhost Processes:

1. lsof -i <PID>
2. kill -9 <PID>

EOF
}

init_project() {
  local target_dir="${1:-.}"
  mkdir -p "$target_dir"
  cd "$target_dir"

  cat > requirements.txt <<'EOF'
# Flask>=2.3.0
Flask==3.0.3
Werkzeug==3.0.1
Jinja2==3.1.4
MarkupSafe==2.1.5
itsdangerous==2.2.0
click==8.1.7
EOF

cat > cia.py <<'EOF'
import os
import zipfile
from flask import Flask, render_template, request, redirect, url_for, abort, send_from_directory
from werkzeug.utils import secure_filename

app = Flask(__name__)

# Configuration
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'zip', '7z', 'rar', 'tar', 'gz'} # Add extensions as needed

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 500 * 1024 * 1024  # Limit uploads to 500MB

# Ensure upload directory exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def get_file_metadata(filepath):
    """
    Extracts metadata without allowing file download.
    For ZIPs, it counts internal files. For others, returns basic OS stats.
    """
    stats = os.stat(filepath)
    size_mb = round(stats.st_size / (1024 * 1024), 2)
    file_type = "Archive"
    internal_count = "N/A"

    # Try to read ZIP metadata specifically
    if filepath.lower().endswith('.zip'):
        try:
            with zipfile.ZipFile(filepath, 'r') as z:
                internal_count = len(z.namelist())
                file_type = "ZIP Archive"
        except zipfile.BadZipFile:
            file_type = "Corrupt ZIP"
    
    return {
        "size": f"{size_mb} MB",
        "type": file_type,
        "contents": internal_count,
        "modified": stats.st_mtime
    }

@app.route('/')
def index():
    files = []
    # List all files in the upload folder
    for filename in os.listdir(app.config['UPLOAD_FOLDER']):
        if allowed_file(filename):
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            meta = get_file_metadata(filepath)
            files.append({
                "name": filename,
                "meta": meta
            })
    # Sort by name
    files.sort(key=lambda x: x['name'])
    return render_template('index.html', files=files)

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return redirect(request.url)
    
    file = request.files['file']
    
    if file.filename == '':
        return redirect(request.url)
    
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
        return redirect(url_for('index'))
    
    return "Invalid file type", 400

# SECURITY CRITICAL: Explicitly block any attempt to download files
@app.route('/uploads/<path:filename>')
def blocked_download(filename):
    """
    This route catches any direct access attempts to the uploads folder
    and returns a 403 Forbidden error.
    """
    abort(403, description="Downloads are disabled for this archive.")

# Optional: Block directory listing via web server config is preferred, 
# but this adds a layer of safety within Flask.
@app.route('/uploads/')
def blocked_directory():
    abort(403, description="Directory listing is disabled.")

if __name__ == '__main__':
    # app.run(debug=True, port=5000)
    # not sure if i need that since its already added above...?
EOF

cat > templates/cia.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>canadian internet archive</title>
    <style>
        :root {
            --bg-color: #1a1a2e;
            --card-bg: #16213e;
            --accent: #0f3460;
            --text: #e94560;
            --text-light: #f1f1f1;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-light);
            margin: 0;
            padding: 20px;
            display: flex;
            flex-direction: column;
            align-items: center;
        }

        h1 { color: var(--text); margin-bottom: 30px; }

        .upload-container {
            background: var(--card-bg);
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.5);
            text-align: center;
            width: 100%;
            max-width: 600px;
            margin-bottom: 40px;
            border: 2px dashed var(--accent);
        }

        input[type="file"] {
            display: none;
        }

        .custom-file-upload {
            border: 1px solid var(--text);
            background: var(--accent);
            color: white;
            display: inline-block;
            padding: 10px 20px;
            cursor: pointer;
            border-radius: 5px;
            transition: background 0.3s;
        }

        .custom-file-upload:hover { background: var(--text); }

        button {
            background: var(--text);
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
            margin-left: 10px;
        }

        button:hover { opacity: 0.9; }

        .file-list {
            width: 100%;
            max-width: 900px;
            border-collapse: collapse;
            background: var(--card-bg);
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 4px 15px rgba(0,0,0,0.5);
        }

        .file-list th, .file-list td {
            padding: 15px;
            text-align: left;
            border-bottom: 1px solid var(--accent);
        }

        .file-list th {
            background-color: var(--accent);
            color: var(--text);
            text-transform: uppercase;
            font-size: 0.85rem;
            letter-spacing: 1px;
        }

        .file-list tr:hover { background-color: rgba(255,255,255,0.05); }

        .badge {
            background: var(--accent);
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.8rem;
            color: #fff;
        }

        .empty-state {
            text-align: center;
            color: #888;
            padding: 40px;
        }
    </style>
</head>
<body>

    <h1>🎮 ROM Archive Manager</h1>

    <!-- Upload Section -->
    <div class="upload-container">
        <h3>Upload New Archive</h3>
        <p style="font-size: 0.9rem; color: #aaa;">Supported: .zip, .7z, .rar (Downloads Disabled)</p>
        <form action="/upload" method="post" enctype="multipart/form-data">
            <label for="file-upload" class="custom-file-upload">
                📂 Choose File
            </label>
            <input id="file-upload" name="file" type="file" required onchange="document.getElementById('file-name').innerText = this.files[0].name">
            <span id="file-name" style="margin-left: 15px; font-style: italic;"></span>
            <br><br>
            <button type="submit">Upload Archive</button>
        </form>
    </div>

    <!-- File List Section -->
    <table class="file-list">
        <thead>
            <tr>
                <th>Filename</th>
                <th>Type</th>
                <th>Size</th>
                <th>Internal Files</th>
                <th>Last Modified</th>
            </tr>
        </thead>
        <tbody>
            {% if files %}
                {% for file in files %}
                <tr>
                    <td><strong>{{ file.name }}</strong></td>
                    <td><span class="badge">{{ file.meta.type }}</span></td>
                    <td>{{ file.meta.size }}</td>
                    <td>{{ file.meta.contents }}</td>
                    <td>{{ file.meta.modified | int | timestamp_to_date }}</td>
                </tr>
                {% endfor %}
            {% else %}
                <tr>
                    <td colspan="5" class="empty-state">No archives uploaded yet.</td>
                </tr>
            {% endif %}
        </tbody>
    </table>

    <script>
        // Simple client-side validation feedback
        document.querySelector('form').onsubmit = function() {
            const btn = document.querySelector('button[type="submit"]');
            btn.innerText = "Uploading...";
            btn.disabled = true;
        };
    </script>
</body>
</html>
EOF

  cat > app.py <<'PY'
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from flask import Flask, abort, redirect, render_template, request

app = Flask(__name__)
DATA_FILE = Path(__file__).resolve().parent / "posts.json"


def load_posts() -> dict[str, Any]:
    if not DATA_FILE.exists():
        return {}
    with DATA_FILE.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def save_posts(posts: dict[str, Any]) -> None:
    with DATA_FILE.open("w", encoding="utf-8") as handle:
        json.dump(posts, handle, indent=2, ensure_ascii=False)


def make_slug(value: str) -> str:
    slug = value.lower().strip()
    slug = slug.replace(" ", "-")
    allowed = "abcdefghijklmnopqrstuvwxyz0123456789-_"
    return "".join(ch for ch in slug if ch in allowed)


@app.route("/", methods=("GET", "POST"))
def index():
    posts = load_posts()

    if request.method == "POST":
        title = request.form.get("title", "").strip()
        content = request.form.get("content", "").strip()
        slug = request.form.get("slug", "").strip() or make_slug(title)

        if not title or not content:
            return render_template("index.html", posts=posts, error="Title and content are required.")

        slug = make_slug(slug)
        if not slug:
            return render_template("index.html", posts=posts, error="Enter a valid slug or title.")
        if slug in posts:
            return render_template("index.html", posts=posts, error="That slug is already in use.")

        posts[slug] = {"title": title, "content": content}
        save_posts(posts)
        return redirect(f"/{slug}")

    return render_template("index.html", posts=posts)


@app.route("/<slug>")
def show_post(slug: str):
    posts = load_posts()
    post = posts.get(slug)
    if post is None:
        abort(404)
    return render_template("post.html", post=post, slug=slug)


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
    # cia date & time functionality
    @app.template_filter('timestamp_to_date')
      def timestamp_to_date_filter(timestamp):
        return datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M')
PY

  mkdir -p templates

  cat > templates/index.html <<'HTML'
<!doctype html>
<html lang="en">

<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>AYT04 - Home</title>
  <style>
    :root {
      --bg: #121417;
      --card: #16181b;
      --muted: #98a0a6;
      --accent: #e56b6b;
      --border: #232528;
      --radius: 10px;
      --container: 760px;
      /* narrower centered content */
      --text: #e6eef3;
      --shadow: 0 8px 24px rgba(0, 0, 0, 0.6);
      --small-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
      --gap: 18px;
    }

    * {
      box-sizing: border-box
    }

    html,
    body {
      height: 100%
    }

    body {
      margin: 0;
      font-family: Inter, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial;
      background: var(--bg);
      color: var(--text);
      -webkit-font-smoothing: antialiased;
      line-height: 1.5;
      display: flex;
      align-items: flex-start;
      justify-content: center;
      padding: 40px 16px;
    }

    /* center card that holds everything */
    .center-card {
      width: 100%;
      max-width: var(--container);
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.01), transparent);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 22px;
      box-shadow: var(--shadow);
    }

    h1 {
      margin: 0 0 14px 0;
      font-family: Georgia, "Times New Roman", serif;
      font-size: 28px;
      font-weight: 600;
      color: var(--text);
    }

    .error {
      color: var(--accent);
      margin: 10px 0;
      font-weight: 600
    }

    form {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 16px;
      box-shadow: var(--small-shadow);
      display: grid;
      gap: 12px;
      margin-bottom: 18px;
    }

    form label {
      display: block;
      font-size: 13px;
      color: var(--muted);
      font-weight: 600
    }

    form input,
    form textarea {
      width: 100%;
      padding: 10px 12px;
      border-radius: 8px;
      border: 1px solid #2b2e31;
      background: #0f1113;
      color: var(--text);
      font-size: 15px;
      outline: none;
      box-shadow: var(--small-shadow);
    }

    form textarea {
      min-height: 120px;
      resize: vertical;
      line-height: 1.6
    }

    form input::placeholder,
    form textarea::placeholder {
      color: #5b6166
    }

    form button[type="submit"] {
      justify-self: start;
      background: var(--accent);
      color: #111;
      border: none;
      padding: 9px 14px;
      border-radius: 8px;
      font-weight: 700;
      cursor: pointer;
      box-shadow: 0 6px 12px rgba(229, 107, 107, 0.12);
    }

    .post-list h2 {
      font-size: 16px;
      color: var(--muted);
      margin: 6px 0 10px;
      font-weight: 700;
      letter-spacing: 0.3px;
    }

    .post-list ul {
      list-style: none;
      padding: 0;
      margin: 0;
      display: grid;
      gap: 12px
    }

    .post-list li {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 12px 14px;
      box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
    }

    .post-list a {
      color: var(--text);
      font-family: Georgia, "Times New Roman", serif;
      font-size: 16px;
      font-weight: 600;
      text-decoration: none;
    }

    .post-list a:hover {
      color: var(--accent);
      text-decoration: underline
    }

    @media (max-width:520px) {
      body {
        padding: 20px 12px
      }

      .center-card {
        padding: 16px
      }

      h1 {
        font-size: 22px
      }
    }

    .rules-sidebar {
      width: 300px;
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      padding: 16px;
      box-shadow: var(--small-shadow);
      display: flex;
      flex-direction: column;
      gap: 12px;
      font-size: 14px;
    }

    .rules-sidebar h2 {
      margin: 0;
      font-size: 15px;
      color: var(--muted);
      letter-spacing: 0.2px;
      font-weight: 700;
    }

    .rule-group-title {
      margin: 0;
      font-size: 13px;
      color: var(--text);
      font-weight: 700;
      margin-top: 6px;
    }

    .rules-list {
      margin: 6px 0 0 18px;
      padding: 0;
      color: var(--muted);
    }

    .rules-list li {
      margin: 8px 0;
      line-height: 1.35;
    }

    .rules-list strong {
      color: var(--text);
      font-weight: 700;
    }

    .rules-footer {
      margin-top: 6px;
      padding-top: 8px;
      border-top: 1px solid rgba(255, 255, 255, 0.02);
    }

    .rules-footer .muted {
      margin: 0;
      color: var(--muted);
      font-size: 13px
    }
  </style>
</head>

<body>
  <h1>The AYT04  Q&amp;</h1>
  {% if error %}
  <p class="error">{{ error }}</p>
  {% endif %}
  <form method="post" autocomplete="off">
    <label>
      Title
      <input name="title" required />
    </label>
    <label>
      Optional slug
      <input name="slug" placeholder="what-year-did-canada-become-a-country" />
    </label>
    <label>
      Content
      <textarea name="content" required></textarea>
    </label>
    <button type="submit">Post</button>
  </form>

  <section class="post-list">
    <h2>Existing posts</h2>
    <ul>
      {% for slug, post in posts.items() %}
      <li><a href="/{{ slug }}">{{ post.title }}</a></li>
      {% else %}
      <li>No posts yet.</li>
      {% endfor %}
    </ul>
  </section>
</body>
<aside class="rules-sidebar" aria-labelledby="rules-title">
  <h2 id="rules-title">Community Rules</h2>

  <section class="rule-group">
    <h3 class="rule-group-title">Be Respectful</h3>
    <ol class="rules-list">
      <li><strong>No harassment:</strong> Personal attacks, hate speech, and threats are not allowed.</li>
      <li><strong>Keep it civil:</strong> Disagree without insulting others.</li>
    </ol>
  </section>

  <section class="rule-group">
    <h3 class="rule-group-title">Content</h3>
    <ol class="rules-list">
      <li><strong>No spam:</strong> Repetitive posts, self-promotion, or referral links are forbidden.</li>
      <li><strong>Stay on-topic:</strong> Posts must relate to the community’s focus.</li>
      <li><strong>No illegal content:</strong> Requests for or distribution of illegal materials are prohibited.</li>
    </ol>
  </section>

  <section class="rule-group">
    <h3 class="rule-group-title">Moderation</h3>
    <ol class="rules-list">
      <li><strong>Follow moderator instructions:</strong> Once you post something, it's permanant, however the admins can remove your post if it deems to violate our rules.</li>
      <li><strong>Report rule-breaking content:</strong> Due to the nature of there not being a account creation, we rely heavily on our team of mods, which is just me and my close friends, we wil remove anythng that deems unrelated to our core focus of our projects.</li>
    </ol>
  </section>
</aside>

</html>
HTML

  cat > templates/post.html <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{{ post.title }}</title>
    <style>
      :root{ --bg:#0f1112; --card:#151618; --muted:#a8b0b6; --accent:#e33b3b; --link:#9fd3ff; --max-width:760px; --radius:10px; --gap:18px; --font-sans: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial; } html,body{ height:100%; margin:0; background:linear-gradient(180deg,var(--bg) 0%, #0b0c0d 100%); color:#e6eef3; font-family:var(--font-sans); -webkit-font-smoothing:antialiased; -moz-osx-font-smoothing:grayscale; line-height:1.5; } /* page wrapper centers content vertically & horizontally */ body{ display:flex; align-items:center; justify-content:center; padding:40px 20px; } /* simple back link styled like a pill button */ a[href="/"]{ position:fixed; left:20px; top:20px; text-decoration:none; color:var(--link); background:rgba(255,255,255,0.03); padding:8px 12px; border-radius:999px; font-weight:600; box-shadow:0 2px 10px rgba(0,0,0,0.6); transition:transform .12s ease, background .12s ease; } a[href="/"]:hover{ transform:translateY(-2px); background:rgba(159,211,255,0.06) } /* article card */ article{ width:100%; max-width:var(--max-width); background:linear-gradient(180deg, rgba(255,255,255,0.02), transparent); border:1px solid rgba(255,255,255,0.04); border-radius:var(--radius); padding:28px; box-shadow: 0 8px 30px rgba(2,6,10,0.7), inset 0 1px 0 rgba(255,255,255,0.02); } /* title */ article h1{ margin:0 0 12px 0; font-size:clamp(20px, 3.8vw, 32px); color:#f7fbff; letter-spacing:-0.2px; } /* content paragraph */ article p{ margin:0; color:var(--muted); font-size:16px; white-space:pre-wrap; /* respects newlines in post.content */ } /* small responsive adjustments */ @media (max-width:520px){ body{ padding:28px 14px; } article{ padding:20px; } a[href="/"]{ left:12px; top:12px; padding:7px 10px; font-size:14px; } }
    </style>
  </head>
  <body>
    <a href="/">← Back</a>
    <article>
      <h1>{{ post.title }}</h1>
      <p>{{ post.content }}</p>
    </article>
  </body>
</html>
HTML

  cat > README.md <<'EOF'
# Community Quora Clone

I made this Quora / UserVoice platform for any small organization
to setup and use for their community. This is light, doesn't require
much maintence, just follow the steps below, and your in!

This simple Flask app stores posts with root-level slugs.

Run:

    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    python app.py

Then visit `http://127.0.0.1:5000/`.

Flask docs: https://flask.palletsprojects.com/en/latest/
EOF

  echo "Project initialized in $(pwd)."
  echo "Run: python app.py"
}

main() {
  if [[ ${#@} -eq 0 ]]; then
    print_help
    exit 0
  fi

  case "$1" in
    init)
      init_project "${2:-.}"
      ;;
    help|--help|-h)
      print_help
      ;;
    *)
      echo "Unknown command: $1"
      print_help
      exit 1
      ;;
  esac
}

main "$@"
