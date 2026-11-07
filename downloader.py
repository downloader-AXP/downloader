import os
import requests
from flask import Flask, Response, render_template_string, stream_with_context

app = Flask(__name__)

# paste your direct download link from Dropbox or Google Drive here
EXTERNAL_FILE_URL = 'https://example.com'
# The name the file will have when the user downloads it
DOWNLOAD_FILENAME = 'your_file.zip' 

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
            <p>Please wait while we fetch your file.</p>
            <p>If it doesn't start, <a href="/download">click here to download</a>.</p>
        </div>
    </body>
    </html>
    """
    return render_template_string(html_content)

@app.route('/download')
def download_file():
    # Make a streaming request to the external cloud host
    req = requests.get(EXTERNAL_FILE_URL, stream=True)
    
    if req.status_code != 200:
        return f"Error: Could not fetch file from external storage. Status code: {req.status_code}", 500

    def generate_chunks():
        # Read from cloud storage in 1MB chunks and immediately send to the user
        for chunk in req.iter_content(chunk_size=1024 * 1024):
            if chunk:
                yield chunk

    # Build the streaming response back to the user's browser
    response = Response(
        stream_with_context(generate_chunks()),
        mimetype="application/octet-stream"
    )
    
    response.headers["Content-Disposition"] = f"attachment; filename={DOWNLOAD_FILENAME}"
    
    # Forward the file size header if the cloud provider gives it to us
    if "Content-Length" in req.headers:
        response.headers["Content-Length"] = req.headers["Content-Length"]
        
    return response

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)
