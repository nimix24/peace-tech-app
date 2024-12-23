from decimal import Decimal
from flask import Flask, request, jsonify
import boto3
import logging
import sys
from datetime import datetime

app = Flask(__name__)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/home/ec2-user/app/dynamo_python.log'),
        #logging.FileHandler(r"G:\logs"),
        logging.StreamHandler(sys.stdout)  # Output to console
    ]
)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb', region_name='us-west-2')
table = dynamodb.Table('greetings_table')

@app.route('/save-message', methods=['POST'])
def save_message():
    try:
        # Extract data from request
        data = request.json
        print("INSIDE /save-message. data = request.json is -> ", data)
        logging.info ("data = request.json coming from flask_app --> ", data)
        if not data:
            return jsonify({'error': 'No data provided'}), 400

        logging.info ("BEFORE table.put_item(Item={")
        logging.info ("'id': str(hash(data['greeting'])) -->", str(hash(data['greeting'])))
        logging.info("data['greeting']  -->" ,data['greeting'])
        logging.info("data['language']  -->", data['language'])
        logging.info("data['sentiment'] -->", data['sentiment'])

        # Get the current date and time
        current_datetime = datetime.now().isoformat()  # ISO 8601 format

        # Save to DynamoDB
        table.put_item(Item={
            'id': str(hash(data['greeting'])),  # Use hash for unique ID
            'greeting': data['greeting'],
            'language': data['language'],
            'sentiment': Decimal(str(data['sentiment'])),
            'date': current_datetime
        })
        logging.info ("AFTER table.put_item(Item={")
        logging.info ("jsonify({'Status': 'Data saved successfully'})  ->", jsonify({'Status': 'Data saved successfully'}))
        return jsonify({'Status': 'Data saved successfully'}), 200

    except Exception as e:
        logging.info ("INSIDE Exception")
        return jsonify({'error': str(e)}), 500

# Run the Flask app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002)
