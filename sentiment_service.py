from flask import Flask, request, jsonify
import nltk
from nltk.sentiment import SentimentIntensityAnalyzer

app = Flask(__name__)
nltk.download('vader_lexicon')

def evaluate_sentiment(text, return_label=False):
    """
        Analyzes sentiment of the given text.

        Args:
            text (str): The text to analyze.
            return_label (bool): If True, return sentiment label (Positive, Negative, Neutral).
                                 If False, return only the compound score.

        Returns:
            float or tuple: Compound score if `return_label` is False,
                            (compound score, sentiment label) if `return_label` is True.
        """

    sia = SentimentIntensityAnalyzer()
    sentiment = sia.polarity_scores(text)   #example: {'neg': 0.2, 'neu': 0.6, 'pos': 0.2, 'compound': -0.1027}
    compound_score = sentiment['compound']

    if return_label:
        # Determine sentiment label based on the compound score
        if compound_score >= 0.05:
            label = "Positive"
        elif compound_score <= -0.05:
            label = "Negative"
        else:
            label = "Neutral"
        return compound_score, label

    return compound_score

@app.route('/analyze-sentiment', methods=['POST'])
def analyze_sentiment():
    try:
        # Extract text from request
        text = request.json.get('text', '')
        print ("text inside analyze-sentiment: " + text)
        if not text:
            return jsonify({'error': 'Text is required'}), 400
        if not isinstance(text, str):
            return jsonify({"error": "Invalid input, 'text' must be a string"}), 400
        # Mock sentiment analysis function
        #def evaluate_sentiment(text):
         #   return {"sentiment": "Positive", "score": 0.95}

        # Analyze sentiment
        sentiment_score = evaluate_sentiment(text)
        #score_with_label = evaluate_sentiment(text, return_label=True)   # For future use to return: Compound Score and Label: (-0.1027, 'Negative')
        #sentiment = {"score": 0.95}
        print ("sentiment score is: " , sentiment_score)
        print ("jsonify(sentiment) --> ", jsonify(sentiment_score))
        return jsonify(sentiment_score), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Run the Flask app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=6003)
