import os
from flask import Flask, send_file, render_template_string

app = Flask(__name__)

# Name of the file inside your GitHub repository
FILE_NAME = 'file.exe' 

@app.route('/')
def home():
    # Modern browsers block instant downloads on empty pages.
    # This renders a simple page that triggers the download automatically.
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <!-- Automatically triggers the download after 1 second -->
        <meta http-equiv="refresh" content="1;url=/download">
        <title>Downloading...</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding-top: 50px; }
        </style>
    </head>
    <body>
        <h1>Your download will begin shortly...</h1>
        <p>If it doesn't start automatically, <a href="/download">click here to download</a>.</p>
    </body>
    </html>
    """
    return render_template_string(html_content)

@app.route('/download')
def download_file():
    # Safely build the path to the file in your repository root
    file_path = os.path.join(app.root_path, FILE_NAME)
    
    if os.path.exists(file_path):
        return send_file(file_path, as_attachment=True)
    
    return f"Error: File '{FILE_NAME}' not found in the repository.", 404

if __name__ == '__main__':
    # Render requires the app to listen on 0.0.0.0 and dynamically assigned PORTs
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)
