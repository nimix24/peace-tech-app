from decimal import Decimal
from flask import Flask, request, jsonify
import boto3

app = Flask(__name__)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb', region_name='us-west-2')
table = dynamodb.Table('greetings_table')

@app.route('/save-message', methods=['POST'])
def save_message():
    try:
        # Extract data from request
        data = request.json
        print ("data = request.json coming from flask_app --> ", data)
        if not data:
            return jsonify({'error': 'No data provided'}), 400

        print ("BEFORE table.put_item(Item={")
        print ("'id': str(hash(data['greeting'])) -->", str(hash(data['greeting'])))
        print("data['greeting'] --> " ,data['greeting'])
        print("data['language'] --> ", data['language'])
        print("sentiment_score", data['sentiment']['score'])
        # Save to DynamoDB
        table.put_item(Item={
            'id': str(hash(data['greeting'])),  # Use hash for unique ID
            'greeting': data['greeting'],
            'language': data['language'],
            #'sentiment': data['sentiment']['sentiment']
            'sentiment_score': Decimal(str(data['sentiment']['score']))
        })
        print ("AFTER table.put_item(Item={")
        print ("jsonify({'Status': 'Data saved successfully'})  ->", jsonify({'Status': 'Data saved successfully'}))
        return jsonify({'Status': 'Data saved successfully'}), 200

    except Exception as e:
        print ("INSIDE Exception")
        return jsonify({'error': str(e)}), 500

# Run the Flask app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002)
