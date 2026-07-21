import os
import hashlib
from datetime import datetime
from flask import Flask, render_template, request, redirect, url_for, flash, send_from_directory, abort
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.config['SECRET_KEY'] = 'canadian-preservation-secret-key' # Change this!
app.config['FILES_DIR'] = os.path.join(os.path.dirname(__file__), 'files')
app.config['MAX_CONTENT_LENGTH'] = 5 * 1024 * 1024 * 1024  # 5GB Max upload

# Ensure directory exists
os.makedirs(app.config['FILES_DIR'], exist_ok=True)

# --- Authentication Setup (Simple Hardcoded Users for Friends) ---
# In production, use a database. Here we simulate trusted friends.
USERS = {
    "admin": "password123",
    "friend1": "preservationist",
    "friend2": "maple_leaf"
}

class User(UserMixin):
    def __init__(self, id):
        self.id = id

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

@login_manager.user_loader
def load_user(user_id):
    if user_id in USERS:
        return User(user_id)
    return None

# --- Helper: Calculate SHA256 ---
def calculate_sha256(filepath):
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

# --- Routes ---

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        if username in USERS and USERS[username] == password:
            user = User(username)
            login_user(user)
            return redirect(url_for('index'))
        flash('Invalid credentials', 'error')
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('index'))

@app.route('/', methods=['GET', 'POST'])
def index():
    # Handle Upload (Only for logged in users)
    if request.method == 'POST':
        if not current_user.is_authenticated:
            abort(403)
        
        if 'file' not in request.files:
            flash('No file part', 'error')
            return redirect(request.url)
        
        file = request.files['file']
        if file.filename == '':
            flash('No selected file', 'error')
            return redirect(request.url)

        if file:
            filename = secure_filename(file.filename)
            # Prevent overwriting existing files by adding timestamp if needed, 
            # but for preservation, exact names might matter. 
            # Here we just save.
            save_path = os.path.join(app.config['FILES_DIR'], filename)
            file.save(save_path)
            flash(f'File "{filename}" uploaded successfully!', 'success')
            return redirect(url_for('index'))

    # List Files
    files = []
    for fname in os.listdir(app.config['FILES_DIR']):
        fpath = os.path.join(app.config['FILES_DIR'], fname)
        if os.path.isfile(fpath):
            stat = os.stat(fpath)
            # Calculate checksum (might be slow for huge dirs, consider caching in DB later)
            # For a small preservation project, calculating on load is okay.
            checksum = calculate_sha256(fpath)
            files.append({
                'name': fname,
                'size': stat.st_size,
                'modified': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M'),
                'checksum': checksum
            })
    
    return render_template('index.html', files=files)

@app.route('/download/<path:filename>')
@login_required  # Only friends can download
def download(filename):
    return send_from_directory(app.config['FILES_DIR'], filename, as_attachment=True)

if __name__ == '__main__':
    app.run(debug=True, port=5000)