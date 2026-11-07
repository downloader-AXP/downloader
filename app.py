import os
import requests
from flask import Flask, Response, render_template_string, stream_with_context

app = Flask(__name__)

# Google Drive direct download link for your specific file
EXTERNAL_FILE_URL = 'https://google.com'

# Sets the exact filename for the user's download
DOWNLOAD_FILENAME = 'file.exe' 

@app.route('/')
def home():
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta http-equiv="refresh" content="1;url=/download">
        <title>Downloading...</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding-top: 50px; background-color: #f9f9f9; }
            .container { max-width: 500px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Your download is starting...</h1>
            <p>Please wait while we fetch your file from Google Drive.</p>
            <p>If it doesn't start, <a href="/download">click here to download</a>.</p>
        </div>
    </body>
    </html>
    """
    return render_template_string(html_content)

@app.route('/download')
def download_file():
    # Stream the file content directly from Google Drive
    req = requests.get(EXTERNAL_FILE_URL, stream=True)
    
    if req.status_code != 200:
        return f"Error: Could not fetch from Google Drive. Status code: {req.status_code}", 500

    def generate_chunks():
        # Stream in 1MB chunks to ensure Render runs efficiently
        for chunk in req.iter_content(chunk_size=1024 * 1024):
            if chunk:
                yield chunk

    response = Response(
        stream_with_context(generate_chunks()),
        mimetype="application/octet-stream"
    )
    
    response.headers["Content-Disposition"] = f"attachment; filename={DOWNLOAD_FILENAME}"
    return response

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)
