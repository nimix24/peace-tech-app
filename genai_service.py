from flask import Flask, request, jsonify
import google.generativeai as genai
import logging

logging.basicConfig(filename='genai_service.log', level=logging.INFO)

app = Flask(__name__)

# Configure Google Generative AI
GOOGLE_API_KEY = 'AIzaSyCcvJfXqCg3ATYTW_aC9c5VdW8zD8C_thM'
genai.configure(api_key=GOOGLE_API_KEY)
model = genai.GenerativeModel("gemini-pro")

# Supported languages
LANGUAGES = ["english", "spanish", "hebrew"]

@app.route('/generate-greeting', methods=['POST'])
def generate_greeting():
    try:
        logging.info("inside def generate_greeting")
        # Get the requested language from the payload
        language = request.json.get('language', 'english').lower()
        logging.info ("language: " +language)
        if language not in LANGUAGES:
            return jsonify({'error': f'Unsupported language. Supported languages: {LANGUAGES}'}), 400

        # Generate greeting with Gemini AI
        response = model.generate_content(f"Write a greeting in {language} in one sentence")
        greeting = response.text
        logging.info("greeting/response is: " + greeting)
        #greeting = f"Hello in {language}!"

        if not greeting:
            return jsonify({'error': 'No greeting generated by Gemini AI'}), 500
        logging.info ("before final return: " , jsonify({'greeting': greeting, 'language': language}))
        return jsonify({'greeting': greeting, 'language': language}), 200

    except Exception as e:
        logging.info ("Inside except Exception as e")
        return jsonify({'error': str(e)}), 500

# Run the Flask app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
