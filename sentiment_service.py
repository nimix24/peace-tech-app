from flask import Flask, request, jsonify

app = Flask(__name__)

# Mock sentiment analysis function
def evaluate_sentiment(text):
    # Placeholder logic: Replace this with an actual model or API call
    if "great" in text.lower() or "good" in text.lower():
        return {"sentiment": "Positive", "score": 0.9}
    elif "bad" in text.lower():
        return {"sentiment": "Negative", "score": 0.7}
    else:
        return {"sentiment": "Neutral", "score": 0.5}

@app.route('/analyze-sentiment', methods=['POST'])
def analyze_sentiment():
    try:
        # Extract text from request
        text = request.json.get('text', '')
        print ("text inside analyze-sentiment" + text)
        if not text:
            return jsonify({'error': 'Text is required'}), 400

        # Mock sentiment analysis function
        #def evaluate_sentiment(text):
         #   return {"sentiment": "Positive", "score": 0.95}

        # Analyze sentiment
        #sentiment = evaluate_sentiment(text)
        sentiment = {"score": 0.95}
        print ("sentiment is: " , sentiment)
        print ("jsonify(sentiment) --> ", jsonify(sentiment))
        return jsonify(sentiment), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Run the Flask app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5003)
