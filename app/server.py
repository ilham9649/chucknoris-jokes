from flask import Flask, render_template
import requests

app = Flask(__name__)

CHUCK_NORRIS_API = "https://api.chucknorris.io/jokes/random"

@app.route('/')
def index():
    try:
        response = requests.get(CHUCK_NORRIS_API, timeout=5)
        response.raise_for_status()
        joke_data = response.json()
        joke = joke_data.get('value', 'Failed to fetch joke')
        icon_url = joke_data.get('icon_url', '')
        joke_id = joke_data.get('id', '')
    except requests.exceptions.RequestException as e:
        joke = f"Unable to fetch joke at the moment. Please try again later."
        icon_url = ''
        joke_id = ''
    except Exception as e:
        joke = f"An unexpected error occurred. Please try again."
        icon_url = ''
        joke_id = ''
    
    return render_template('index.html', joke=joke, icon_url=icon_url, joke_id=joke_id)

@app.route('/health')
def health():
    return {'status': 'healthy', 'service': 'chucknoris-jokes'}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
