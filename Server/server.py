from flask import Flask, request, jsonify, send_file
import yt_dlp
import os
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

def get_video_formats(url):
    """Retrieve available video formats from the YouTube URL."""
    ydl_opts = {}
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info_dict = ydl.extract_info(url, download=False)
        formats = info_dict.get('formats', [])

    # Filter and return video formats
    video_formats = []
    for f in formats:
        if f['vcodec'] != 'none':  # Only video formats
            video_formats.append({
                'format_id': f['format_id'],
                'format_note': f.get('format_note', ''),
                'ext': f['ext'],
                'filesize': f.get('filesize', None)
            })
    return video_formats

@app.route('/get_formats', methods=['POST'])
def get_formats():
    """Endpoint to get available formats for a given URL."""
    data = request.json
    url = data.get('url')

    try:
        video_formats = get_video_formats(url)
        return jsonify(video_formats), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 400

def download_video(url, format_code):
    """Download the video in the selected format."""
    ydl_opts = {
        'format': format_code,
        'outtmpl': 'downloads/%(title)s.%(ext)s',
        'postprocessors': [{
            'key': 'FFmpegVideoConvertor',  # Convert to desired format if necessary
            'preferedformat': 'mp4',         # Or another format if desired
        }],
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info_dict = ydl.extract_info(url)
        return ydl.prepare_filename(info_dict)  # Returns the file path of the downloaded file

@app.route('/download', methods=['POST'])
def download():
    """Download the video in the selected format."""
    data = request.json
    url = data.get('url')
    format_code = data.get('format', 'best')

    try:
        file_name = download_video(url, format_code)
        return send_file(file_name, as_attachment=True)  # Send file to the client
    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
    if not os.path.exists('downloads'):
        os.makedirs('downloads')
    app.run(debug=True, port=7777)
